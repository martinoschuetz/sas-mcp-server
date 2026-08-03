# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""SAS Viya compute session and job orchestration.

These helpers drive the Compute service end to end: resolve a compute context,
open a session, submit code, and poll for completion. ``run_one_snippet`` is
the public entry point used by the ``execute_sas_code`` MCP tool.

To avoid paying the (slow) session spin-up cost on every call, compute sessions
are pooled by :class:`_ComputeSessionCache`: one reusable session per
authenticated user and compute context. Because compute sessions are stateful,
SAS WORK tables, macro variables, and assigned librefs persist across calls
until the session is reset (``reset_cached_session``) or reaped by Viya for
inactivity. Generic REST helpers and the shared client/logger live in
:mod:`sas_mcp_server.viya_client`.
"""

import asyncio
import base64
import binascii
import hashlib
import json
import ssl
import time

import httpx
from cachetools import TTLCache

from .config import CONTEXT_NAME, SSL_VERIFY, VIYA_ENDPOINT
from .viya_client import logger, make_client, SharedAsyncClient

# Caching for performance
# Cache data selection lists for 60 seconds, max 100 different filter combinations
data_selection_cache = TTLCache(maxsize=100, ttl=60)

# Create a permissive SSL context that we can use globally if SSL_VERIFY is disabled
_permissive_ssl_context = ssl.create_default_context()
_permissive_ssl_context.check_hostname = False
_permissive_ssl_context.verify_mode = ssl.CERT_NONE



async def get_context_id(client: httpx.AsyncClient, context_name: str) -> str:
    """Return the id of the named compute context, raising if it is absent."""
    url = f"{VIYA_ENDPOINT}/compute/contexts"
    resp = await client.get(url, params={"name": context_name})
    resp.raise_for_status()
    coll = resp.json()
    items = coll.get("items", [])
    if not items:
        raise RuntimeError(f"Compute context not found: {context_name}")
    return items[0]["id"]


async def create_session(
    client: httpx.AsyncClient, context_id: str, name: str = "py-parallel"
) -> str:
    """Create a compute session in *context_id* and return its id."""
    url = f"{VIYA_ENDPOINT}/compute/contexts/{context_id}/sessions"
    resp = await client.post(url, json={"name": name})
    resp.raise_for_status()
    return resp.json()["id"]


async def delete_session(client: httpx.AsyncClient, sid: str) -> None:
    try:
        delete_url = f"{VIYA_ENDPOINT}/compute/sessions/{sid}"
        await client.delete(delete_url)
        logger.info("Session %s deleted successfully", sid)
    except Exception:
        logger.exception("Failed to delete session %s", sid)
        raise


def _token_user_key(token: str) -> str:
    """Derive a stable per-user cache key from a Viya access token.

    Viya access tokens are JWTs; we read the ``sub`` claim (falling back to
    other identity claims) *without* verifying the signature — the auth layer
    has already validated the token. If the token is not a decodable JWT we
    fall back to a hash of the token string.
    """
    raw = token[7:] if token.startswith("Bearer ") else token
    parts = raw.split(".")
    if len(parts) >= 2:
        payload_b64 = parts[1] + "=" * (-len(parts[1]) % 4)
        try:
            payload = json.loads(base64.urlsafe_b64decode(payload_b64))
            for claim in ("sub", "uid", "user_name", "user_id"):
                value = payload.get(claim)
                if value:
                    return f"{claim}:{value}"
        except (binascii.Error, ValueError, json.JSONDecodeError):
            pass
    return "token:" + hashlib.sha256(raw.encode()).hexdigest()[:16]


async def _session_is_alive(client: httpx.AsyncClient, session_id: str) -> bool:
    """Return ``True`` if *session_id* still exists server-side."""
    try:
        resp = await client.get(f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/state")
    except httpx.HTTPError:
        return False
    return resp.status_code == 200


class _ComputeSessionCache:
    """Process-wide pool of reusable compute sessions, keyed by (user, context).

    One session is kept per authenticated user and compute context so repeat
    tool calls skip the costly session spin-up. A per-key lock serialises the
    create/reset of a given session without blocking unrelated keys.
    """

    SESSION_NAME = "sas-mcp-shared"

    def __init__(self) -> None:
        # key -> (session_id, most recent token seen for that session, last_checked_time).
        # The token is kept so :meth:`shutdown` can authenticate the delete calls.
        self._sessions: dict[tuple[str, str], tuple[str, str, float]] = {}
        self._locks: dict[tuple[str, str], asyncio.Lock] = {}
        self._guard = asyncio.Lock()
        self.check_interval = 30.0

    async def _lock_for(self, key: tuple[str, str]) -> asyncio.Lock:
        async with self._guard:
            lock = self._locks.get(key)
            if lock is None:
                lock = asyncio.Lock()
                self._locks[key] = lock
            return lock

    async def get_or_create(
        self, client: httpx.AsyncClient, context_name: str, user_key: str, token: str
    ) -> str:
        """Return a live session id for (user_key, context_name).

        Creates a session when none is cached or the cached one has been reaped
        server-side (detected via :func:`_session_is_alive`). *token* is stored
        alongside the session for shutdown cleanup.
        """
        key = (user_key, context_name)
        lock = await self._lock_for(key)
        async with lock:
            cached = self._sessions.get(key)
            if cached is not None:
                sid, cached_token, last_checked = cached
                now = time.time()
                # Skip HTTP state check if session was created/reused less than self.check_interval ago
                if now - last_checked < self.check_interval or await _session_is_alive(client, sid):
                    logger.info("Reusing cached compute session %s", sid)
                    # Keep the freshest token so shutdown cleanup can authenticate.
                    self._sessions[key] = (sid, token, now)
                    return sid
                logger.info("Cached compute session %s is gone; recreating", sid)
                self._sessions.pop(key, None)
            context_id = await get_context_id(client, context_name)
            sid = await create_session(client, context_id, name=self.SESSION_NAME)
            self._sessions[key] = (sid, token, time.time())
            logger.info("Created and cached compute session %s", sid)
            return sid

    async def reset(
        self, client: httpx.AsyncClient, context_name: str, user_key: str
    ) -> str | None:
        """Drop the cached session for (user_key, context_name) and delete it.

        Returns the deleted session id, or ``None`` if nothing was cached.
        """
        key = (user_key, context_name)
        lock = await self._lock_for(key)
        async with lock:
            cached = self._sessions.pop(key, None)
        if cached is None:
            return None
        sid, _, _ = cached
        await delete_session(client, sid)
        return sid

    async def shutdown(self) -> None:
        """Delete every cached compute session server-side (best effort).

        Called from the server lifespan on shutdown so warm sessions do not
        linger until Viya reaps them. Each session is deleted with the most
        recent token seen for it; failures (e.g. an expired token) are logged
        and ignored, since Viya reaps an orphaned session on idle timeout.
        """
        async with self._guard:
            entries = list(self._sessions.values())
            self._sessions.clear()
            self._locks.clear()
        if not entries:
            return
        logger.info("Deleting %d cached compute session(s) on shutdown", len(entries))
        for entry in entries:
            sid, token = entry[0], entry[1]
            try:
                async with make_client(token) as client:
                    await delete_session(client, sid)
            except Exception:
                logger.warning(
                    "Could not delete compute session %s on shutdown", sid, exc_info=True
                )

    def clear(self) -> None:
        """Forget all cached sessions without deleting them server-side.

        Used to isolate unit tests; not part of normal operation.
        """
        self._sessions.clear()
        self._locks.clear()
        self.check_interval = 0.0


_SESSION_CACHE = _ComputeSessionCache()


async def get_cached_session(
    client: httpx.AsyncClient, context_name: str, token: str
) -> str:
    """Return the reusable compute session id for the token's user + context."""
    return await _SESSION_CACHE.get_or_create(
        client, context_name, _token_user_key(token), token
    )


async def reset_cached_session(
    client: httpx.AsyncClient, context_name: str, token: str
) -> str | None:
    """Delete and forget the cached compute session for the token's user.

    Returns the deleted session id, or ``None`` if there was no cached session.
    """
    return await _SESSION_CACHE.reset(client, context_name, _token_user_key(token))


async def shutdown_session_cache() -> None:
    """Delete all cached compute sessions server-side (call from server lifespan)."""
    await _SESSION_CACHE.shutdown()


def clear_session_cache() -> None:
    """Forget all cached compute sessions (test isolation helper)."""
    _SESSION_CACHE.clear()


async def submit_job(client: httpx.AsyncClient, session_id: str, code: str) -> str:
    """Submit *code* as a job in *session_id* and return the job id."""
    body = {"code": code.splitlines()}
    url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs"
    resp = await client.post(url, json=body)
    job = resp.json()
    return job["id"]


async def wait_job(
    client: httpx.AsyncClient, session_id: str, job_id: str, poll: float = 2
) -> tuple[str, str, str]:
    """Poll *job_id* until it reaches a terminal state; return (state, log, listing)."""
    while True:
        state_url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs/{job_id}/state"
        resp = await client.get(state_url)
        state = resp.text.strip()
        if state in ("completed", "error", "warning", "canceled"):
            # Fetch log
            log_url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs/{job_id}/log?limit=10000"
            log_resp = await client.get(log_url)
            log = log_resp.json()
            lines = [item["line"] for item in log.get("items", [])]
            log_text = "\n".join(lines)

            # Fetch listing (plain text output)
            listing_url = (
                f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs/{job_id}/listing"
            )
            listing_resp = await client.get(listing_url)
            listing_json = listing_resp.json()
            listing_lines = [item["line"] for item in listing_json.get("items", [])]
            listing_text = (
                "\n".join(listing_lines) if listing_lines else "(no listing output)"
            )

            return state, log_text, listing_text
        await asyncio.sleep(poll)


async def run_one_snippet(
    snippet_data: str, snippet_id: str, token: str
) -> dict[str, str]:
    """Execute one SAS snippet end to end and return its structured result.

    Returns a dict with keys ``snippet_id``, ``state``, ``log`` and ``listing``.
    The snippet runs in the caller's cached compute session, so SAS state (WORK
    tables, macro variables, assigned librefs) persists across calls until the
    session is reset via ``reset_cached_session`` or reaped by Viya. The session
    is intentionally *not* torn down here so the next call can reuse it.
    """
    code = snippet_data

    logger.info("Running snippet (token length: %d)", len(token))

    async with make_client(token) as client:
        sid = await get_cached_session(client, CONTEXT_NAME, token)
        try:
            jid = await submit_job(client, sid, code)
            logger.info("Job submitted: %s", jid)
            state, log_text, listing_text = await wait_job(client, sid, jid)
            logger.info("Job completed: %s", state)
            return {
                "snippet_id": snippet_id,
                "state": state,
                "log": log_text,
                "listing": listing_text,
            }
        except Exception:
            logger.exception("Error executing SAS job")
            raise


# ---------------------------------------------------------------------------
# Generic API helpers (used by IoT/CAS tools)
# ---------------------------------------------------------------------------

_utils_client_cache = {}

def _make_client(token):
    """Create or return a cached SharedAsyncClient with auth headers for Viya API calls."""
    if not token.startswith("Bearer "):
        token = f"Bearer {token}"
        
    if token in _utils_client_cache:
        cached_client = _utils_client_cache[token]
        if not cached_client.is_closed:
            return cached_client
            
    headers = {"Authorization": token, "Content-Type": "application/json"}
    
    # Use permissive context if SSL_VERIFY is False
    verify_param = SSL_VERIFY
    if not SSL_VERIFY:
        verify_param = _permissive_ssl_context

    client = SharedAsyncClient(headers=headers, verify=verify_param, timeout=300.0)
    _utils_client_cache[token] = client
    return client


async def _get_json(url, client, params=None, accept="application/json"):
    """GET a JSON response from a Viya REST endpoint."""
    full_url = f"{VIYA_ENDPOINT}{url}"
    resp = await client.get(full_url, headers={"Accept": accept}, params=params or {})
    resp.raise_for_status()
    return resp.json()


async def _get_paged_items(url, client, limit=20, start=0, filters=None, extra_params=None):
    """GET a paginated collection and return the items list plus total count."""
    params = {"start": start, "limit": limit}
    if filters:
        params["filter"] = filters
    if extra_params:
        params.update(extra_params)
    data = await _get_json(url, client, params=params,
                           accept="application/vnd.sas.collection+json")
    return data.get("items", []), data.get("count", 0)


async def _post_json(url, client, body=None, params=None, accept="application/json"):
    """POST JSON to a Viya REST endpoint and return the response JSON."""
    full_url = f"{VIYA_ENDPOINT}{url}"
    resp = await client.post(full_url, json=body, headers={"Accept": accept},
                             params=params or {})
    resp.raise_for_status()
    if resp.status_code == 204 or not resp.content:
        return {}
    return resp.json()


async def _put_json(url, client, body=None, params=None, accept="application/json", if_match=None):
    """PUT JSON to a Viya REST endpoint."""
    full_url = f"{VIYA_ENDPOINT}{url}"
    headers = {"Accept": accept, "Content-Type": "application/json"}
    if if_match:
        headers["If-Match"] = if_match
    
    resp = await client.put(full_url, json=body, headers=headers, params=params or {})
    resp.raise_for_status()
    if resp.status_code == 204 or not resp.content:
        return {}
    return resp.json()


async def _put_data(url, client, data, content_type="text/csv", params=None):
    """PUT raw data (e.g. CSV upload) to a Viya REST endpoint."""
    full_url = f"{VIYA_ENDPOINT}{url}"
    resp = await client.put(full_url, content=data,
                            headers={"Content-Type": content_type},
                            params=params or {})
    resp.raise_for_status()
    if resp.status_code == 204 or not resp.content:
        return {}
    return resp.json()


async def _delete_resource(url, client):
    """DELETE a Viya REST resource."""
    full_url = f"{VIYA_ENDPOINT}{url}"
    resp = await client.delete(full_url)
    resp.raise_for_status()


# ---------------------------------------------------------------------------
# SAS Analytics for IoT (AIoT) Service Helpers
# ---------------------------------------------------------------------------

async def list_data_selections(token: str, filter_query: str = None, start: int = 0, limit: int = 10) -> dict:
    """Lists available SAS Analytics for IoT data selections with TTL caching."""
    cache_key = (filter_query, start, limit)
    if cache_key in data_selection_cache:
        logger.info(f"Returning cached results for data selection list: {cache_key}")
        return data_selection_cache[cache_key]

    params = {"start": start, "limit": limit}
    if filter_query:
        params["filter"] = filter_query
    
    async with _make_client(token) as client:
        result = await _get_json("/dataSelection/dataSelections", client, 
                                 params=params, 
                                 accept="application/vnd.sas.collection+json")
        data_selection_cache[cache_key] = result
        return result


async def get_data_selection(selection_id: str, token: str) -> dict:
    """Retrieves detailed information for a specific SAS AIoT data selection."""
    async with _make_client(token) as client:
        return await _get_json(f"/dataSelection/dataSelections/{selection_id}", client,
                               accept="application/vnd.sas.data.selection+json")


async def update_data_selection(selection_id: str, selection_data: dict, token: str) -> dict:
    """Updates a specific SAS AIoT data selection."""
    async with _make_client(token) as client:
        # Fetch current state to get ETag for optimistic concurrency
        url = f"/dataSelection/dataSelections/{selection_id}"
        resp = await client.get(f"{VIYA_ENDPOINT}{url}", 
                                headers={"Accept": "application/vnd.sas.data.selection+json"})
        resp.raise_for_status()
        etag = resp.headers.get("ETag")
        
        return await _put_json(url, client, body=selection_data,
                               accept="application/vnd.sas.data.selection+json",
                               if_match=etag)


async def delete_data_selection(selection_id: str, token: str) -> None:
    """Deletes a SAS AIoT data selection."""
    async with _make_client(token) as client:
        await _delete_resource(f"/dataSelection/dataSelections/{selection_id}", client)


async def launch_data_selection(selection_id: str, token: str) -> dict:
    """Triggers a launch job for a specific data selection."""
    async with _make_client(token) as client:
        return await _post_json(f"/dataSelection/dataSelections/{selection_id}/launches", client,
                                body={},
                                accept="application/vnd.sas.data.selection.launch+json")


async def copy_data_selection(selection_id: str, new_name: str, token: str, new_description: str = "") -> dict:
    """Copies a specific SAS AIoT data selection."""
    async with _make_client(token) as client:
        body = {"name": new_name, "description": new_description}
        return await _post_json(f"/dataSelection/dataSelections/{selection_id}/copy", client,
                                body=body,
                                accept="application/vnd.sas.data.selection+json")


async def copy_data_selections(selection_ids: list[str], token: str) -> dict:
    """Copies multiple SAS AIoT data selections."""
    async with _make_client(token) as client:
        body = {"resources": selection_ids}
        return await _post_json("/dataSelection/dataSelectionActions/copies", client,
                                body=body,
                                accept="application/json")


async def list_iot_projects(token: str) -> dict:
    """Lists project instances from the IoT analysis service."""
    async with _make_client(token) as client:
        return await _get_json("/iotAnalysis/projects", client,
                               accept="application/vnd.sas.collection+json")


async def list_iot_analyses(token: str, start: int = None, limit: int = None) -> dict:
    """Lists all defined SAS Analytics for IoT analyses."""
    params = {}
    if start is not None:
        params["start"] = start
    if limit is not None:
        params["limit"] = limit
    async with _make_client(token) as client:
        return await _get_json("/iotAnalysis/analyses", client,
                               params=params or None,
                               accept="application/vnd.sas.collection+json")


async def get_iot_analysis(analysis_id: str, token: str) -> dict:
    """Retrieves the full definition of an IoT analysis."""
    async with _make_client(token) as client:
        return await _get_json(f"/iotAnalysis/analyses/{analysis_id}", client,
                               accept="application/vnd.sas.iot.analysis+json")


async def create_iot_analysis(
    name: str,
    model_name: str,
    data_selection_id: str,
    token: str,
    folder_id: str = None,
    parent_instance_id: str = None,
    parent_step_id: str = None,
    subset_group_name: str = None,
    filter_criteria: list = None
) -> dict:
    """Creates a new IoT analysis instance."""
    async with _make_client(token) as client:
        body = {
            "name": name,
            "modelName": model_name,
            "dataSelectionId": data_selection_id
        }
        if folder_id:
            body["folderID"] = folder_id
        if parent_instance_id:
            body["parentInstanceId"] = parent_instance_id
        if parent_step_id:
            body["parentStepId"] = parent_step_id
        if subset_group_name:
            body["subsetGroupName"] = subset_group_name
        if filter_criteria:
            body["filterCriteria"] = filter_criteria
        
        # Wrapped in a collection for this particular endpoint
        collection_body = {
            "name": "analysis",
            "items": [body]
        }
        
        return await _post_json("/iotAnalysis/analyses", client,
                                body=collection_body,
                                accept="application/json")


async def create_and_run_analysis(
    name: str,
    model_name: str,
    data_selection_id: str,
    token: str,
    folder_id: str = None,
    parameter_updates: dict = None,
    wait_for_completion: bool = True,
    parent_instance_id: str = None,
    parent_step_id: str = None,
    subset_group_name: str = None,
    filter_criteria: list = None
) -> dict:
    """Creates a new IoT analysis instance, updates its parameters, and runs it."""
    # 1. Create analysis
    creation_res = await create_iot_analysis(
        name, model_name, data_selection_id, token, folder_id,
        parent_instance_id, parent_step_id, subset_group_name, filter_criteria
    )
    items = creation_res.get("items", [])
    if not items:
        return creation_res
    analysis_id = items[0]["id"]

    async with _make_client(token) as client:
        # 2. Get full details to retrieve steps, inputParameters, and ETag
        url = f"/iotAnalysis/analyses/{analysis_id}"
        resp_get = await client.get(
            f"{VIYA_ENDPOINT}{url}",
            headers={"Accept": "application/vnd.sas.iot.analysis+json"}
        )
        resp_get.raise_for_status()
        etag = resp_get.headers.get("ETag")
        analysis_details = resp_get.json()

        steps = analysis_details.get("steps", [])
        if steps and parameter_updates:
            # We assume single-step models (like PARETO, TREND, DETAIL)
            step = steps[0]
            
            # Map parameterName -> parameter object to update values
            new_params = []
            for p in step.get("inputParameters", []):
                pname = p.get("parameterName", "").strip()
                new_p = dict(p)
                # Find matching update key (case-insensitive)
                for uk, uv in parameter_updates.items():
                    if uk.upper() == pname.upper() and uv is not None:
                        new_p["parameterValue"] = str(uv)
                        break
                new_params.append(new_p)
                
            step["inputParameters"] = new_params
            analysis_details["steps"] = [step]

            # 3. Update the parameters via PUT
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}{url}",
                json=analysis_details,
                headers={
                    "Content-Type": "application/vnd.sas.iot.analysis+json",
                    "Accept": "application/vnd.sas.iot.analysis+json",
                    "If-Match": etag
                }
            )
            resp_put.raise_for_status()
            analysis_details = resp_put.json()

        # 4. Trigger the job
        step_id = steps[0]["id"] if steps else analysis_id
        job_url = f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs"
        run_res = await _post_json(job_url, client, body={}, accept="application/json")
        
        # 5. Wait for completion if requested
        if wait_for_completion:
            job_id = run_res.get("id")
            if job_id:
                job_exec_url = f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs/{job_id}"
                poll_res = await poll_job(job_exec_url, token)
                return {
                    "analysis": analysis_details,
                    "job": poll_res
                }
        
        return {
            "analysis": analysis_details,
            "job": run_res
        }


async def delete_iot_analysis(analysis_id: str, token: str) -> None:
    """Deletes a SAS AIoT analysis."""
    async with _make_client(token) as client:
        await _delete_resource(f"/iotAnalysis/analyses/{analysis_id}", client)


async def run_iot_analysis(analysis_id: str, token: str) -> dict:
    """Submits a job to run a specific IoT analysis."""
    async with _make_client(token) as client:
        try:
            # Try the direct jobs endpoint first
            return await _post_json(f"/iotAnalysis/analyses/{analysis_id}/jobs", client,
                                    body={},
                                    accept="application/vnd.sas.iot.analysis.job+json")
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                # Fallback: find the first step ID and run that
                analysis = await get_iot_analysis(analysis_id, token)
                steps = analysis.get("steps", [])
                if not steps:
                    raise RuntimeError(f"No steps found for analysis {analysis_id}") from e
                step_id = steps[0]["id"]
                return await _post_json(f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs", client,
                                        body={},
                                        accept="application/json")
            raise


async def copy_iot_analyses(analysis_ids: list[str], token: str) -> dict:
    """Copies multiple IoT analyses."""
    async with _make_client(token) as client:
        body = {
            "version": 1,
            "resources": analysis_ids
        }
        return await _post_json("/iotAnalysis/analysisActions/copies", client,
                                body=body,
                                accept="application/json")


async def get_iot_analysis_job(analysis_id: str, job_id: str, token: str) -> dict:
    """Retrieves the status and results of a specific IoT analysis job."""
    async with _make_client(token) as client:
        # Note: Depending on context, job_id might be under /jobExecution/jobs
        # or /iotAnalysis/analyses/{id}/jobs/{job_id}.
        # The tool implementation currently assumes the latter.
        return await _get_json(f"/iotAnalysis/analyses/{analysis_id}/jobs/{job_id}", client,
                               accept="application/vnd.sas.iot.analysis.job+json")


async def list_iot_models(token: str) -> dict:
    """Lists all registered models in SAS Analytics for IoT."""
    async with _make_client(token) as client:
        return await _get_json("/iotAnalysisModels/models", client,
                               accept="application/vnd.sas.collection+json")


async def get_iot_model(model_name: str, token: str) -> dict:
    """Retrieves metadata for a specific AIoT model."""
    async with _make_client(token) as client:
        return await _get_json(f"/iotAnalysisModels/models/{model_name}", client,
                               accept="application/vnd.sas.iot.analysis.model.detail+json")


# ---------------------------------------------------------------------------
# CAS Management Service Helpers
# ---------------------------------------------------------------------------

async def get_cas_summary_statistics(server_id: str, caslib_name: str, table_name: str, token: str) -> dict:
    """Retrieves summary statistics for a CAS table."""
    async with _make_client(token) as client:
        url = f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}/summaryStatistics"
        return await _get_json(url, client, accept="application/vnd.sas.collection+json")


# ---------------------------------------------------------------------------
# High-Level Workflow Orchestration
# ---------------------------------------------------------------------------

async def poll_job(job_url: str, token: str, poll_interval: int = 5) -> dict:
    """Polls a job status until it reaches a terminal state."""
    async with _make_client(token) as client:
        while True:
            resp = await client.get(f"{VIYA_ENDPOINT}{job_url}", headers={"Accept": "application/json"})
            resp.raise_for_status()
            status_data = resp.json()
            state = status_data.get("state")
            if state in ["completed", "failed", "cancelled"]:
                return status_data
            await asyncio.sleep(poll_interval)


async def set_data_selection_date_range(selection_id: str, start_date: str, end_date: str, token: str) -> dict:
    """Updates the MEASURE_DTTM range for a data selection."""
    selection = await get_data_selection(selection_id, token)
    new_values = [start_date, end_date]
    
    modified = False
    for group_id in selection.get("filterCriteria", {}):
        for criterion in selection["filterCriteria"][group_id]:
            if criterion.get("columnName") == "MEASURE_DTTM":
                criterion["values"] = new_values
                modified = True
    
    if not modified:
        raise ValueError(f"No MEASURE_DTTM filter found in data selection {selection_id}")
    
    return await update_data_selection(selection_id, selection, token)


async def run_iot_analysis_and_wait(analysis_id: str, token: str) -> dict:
    """Runs an IoT analysis and waits for completion."""
    job_result = await run_iot_analysis(analysis_id, token)
    
    # Extract job URL
    job_url = None
    for link in job_result.get("links", []):
        if link["rel"] == "job":
            job_url = link["href"]
            break
    
    if not job_url:
        # Fallback for direct job objects
        job_url = f"/jobExecution/jobs/{job_result.get('id')}" if job_result.get("id") else None

    if not job_url:
         raise RuntimeError(f"Could not find job URL in run response for analysis {analysis_id}")
    
    return await poll_job(job_url, token)


async def launch_data_selection_and_wait(selection_id: str, token: str) -> dict:
    """Launches a data selection and waits for completion."""
    launch_result = await launch_data_selection(selection_id, token)
    # Launches in AIoT are jobs too
    job_url = f"/jobExecution/jobs/{launch_result.get('id')}"
    return await poll_job(job_url, token)


async def list_folders_and_projects(token: str, folder_id: str = None) -> dict:
    """Lists folders and projects under a specific folder (or root if not specified)."""
    async with _make_client(token) as client:
        if not folder_id:
            # Fetch root folders
            roots_resp = await _get_json(
                "/folders/rootFolders?limit=1000",
                client,
                accept="application/vnd.sas.collection+json"
            )
            # Also resolve @myFolder shortcut to include in roots
            try:
                my_folder = await _get_json(
                    "/folders/folders/@myFolder",
                    client,
                    accept="application/vnd.sas.content.folder+json"
                )
                my_folder["is_my_folder"] = True
                roots_items = roots_resp.get("items", [])
                if not any(item["id"] == my_folder["id"] for item in roots_items):
                    roots_items.insert(0, my_folder)
                roots_resp["items"] = roots_items
            except Exception:
                pass
            return roots_resp
        else:
            # Fetch folder members
            return await _get_json(
                f"/folders/folders/{folder_id}/members?limit=1000",
                client,
                accept="application/vnd.sas.collection+json"
            )


async def create_folder(name: str, token: str, parent_folder_id: str = "@myFolder", description: str = None) -> dict:
    """Creates a new folder under a parent folder."""
    async with _make_client(token) as client:
        parent_uri = f"/folders/folders/{parent_folder_id}"
        body = {
            "name": name,
            "description": description or ""
        }
        url = f"{VIYA_ENDPOINT}/folders/folders?parentFolderUri={parent_uri}"
        resp = await client.post(url, json=body, headers={
            "Accept": "application/vnd.sas.content.folder+json",
            "Content-Type": "application/json"
        })
        resp.raise_for_status()
        return resp.json()


async def create_project(name: str, token: str, folder_id: str = "@myFolder", description: str = None) -> dict:
    """Creates a new IoT project under a folder."""
    async with _make_client(token) as client:
        folder_uri = folder_id if folder_id.startswith("/folders/folders/") else f"/folders/folders/{folder_id}"
        body = {
            "name": name,
            "description": description or "",
            "folderUri": folder_uri,
            "version": "1"
        }
        url = f"{VIYA_ENDPOINT}/iotAnalysis/projects"
        resp = await client.post(url, json=body, headers={
            "Accept": "application/vnd.sas.iot.project+json",
            "Content-Type": "application/vnd.sas.iot.project+json"
        })
        resp.raise_for_status()
        return resp.json()


async def delete_folder(folder_id: str, token: str) -> None:
    """Deletes a folder by ID."""
    async with _make_client(token) as client:
        await _delete_resource(f"/folders/folders/{folder_id}", client)


async def delete_project(project_id: str, token: str) -> None:
    """Deletes an IoT project by ID."""
    async with _make_client(token) as client:
        await _delete_resource(f"/iotAnalysis/projects/{project_id}", client)


