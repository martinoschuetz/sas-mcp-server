# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import asyncio
import httpx
import ssl
from cachetools import TTLCache
from fastmcp import utilities
from .config import VIYA_ENDPOINT, CONTEXT_NAME

logger = utilities.logging.get_logger(__name__)

# Caching for performance
# Cache data selection lists for 60 seconds, max 100 different filter combinations
data_selection_cache = TTLCache(maxsize=100, ttl=60)

# Create a permissive SSL context that we can use globally
_permissive_ssl_context = ssl.create_default_context()
_permissive_ssl_context.check_hostname = False
_permissive_ssl_context.verify_mode = ssl.CERT_NONE

# ---------------------------------------------------------------------------
# Generic API helpers (used by new tools)
# ---------------------------------------------------------------------------

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


def _make_client(token):
    """Create an httpx.AsyncClient with auth headers for Viya API calls."""
    if not token.startswith("Bearer "):
        token = f"Bearer {token}"
    headers = {"Authorization": token, "Content-Type": "application/json"}
    
    # Explicitly use the permissive SSL context if SSL_VERIFY is disabled
    from .patch_httpx import SSL_VERIFY
    verify_param = _permissive_ssl_context if not SSL_VERIFY else True
    
    return httpx.AsyncClient(headers=headers, verify=verify_param, timeout=300.0)


# ---------------------------------------------------------------------------
# Original helpers (log/listing fetching)
# ---------------------------------------------------------------------------

async def _get_text(url, client, verify=True, extra_params=None):
    # Try text/plain in one shot
    full_url = f"{VIYA_ENDPOINT}{url}"
    r = await client.get(
        full_url, headers={"Accept": "text/plain"}, params=extra_params or {}
    )
    if r.status_code == 200 and r.headers.get("Content-Type", "").startswith(
        "text/plain"
    ):
        return r.text
    # Some deployments need an explicit query hint
    r = await client.get(
        full_url,
        headers={"Accept": "text/plain"},
        params={**(extra_params or {}), "type": "text"},
    )
    if r.status_code == 200 and r.headers.get("Content-Type", "").startswith(
        "text/plain"
    ):
        return r.text
    return None  # caller will fallback to paged JSON


async def _get_paged_lines(url, client, page_limit=10000):
    start = 0
    lines = []
    headers = {"Accept": "application/vnd.sas.collection+json"}
    full_url = f"{VIYA_ENDPOINT}{url}"
    while True:
        resp = await client.get(
            full_url, headers=headers, params={"start": start, "limit": page_limit}
        )
        resp.raise_for_status()
        data = resp.json()
        items = data.get("items", [])
        if not items:
            break
        # items can be dicts like {"line": "..."} or {"text": "..."} depending on endpoint
        for it in items:
            lines.append(it.get("line") or it.get("text") or "")
        if len(items) < page_limit:
            break
        start += page_limit
    return "\n".join(lines)


async def fetch_full_job_log(client, session_id, job_id):
    base = f"/compute/sessions/{session_id}/jobs/{job_id}"
    # 1) Try whole job log as text
    text = await _get_text(f"{base}/log", client)
    if text is not None:
        return text
    # 2) Fallback to paged JSON
    return await _get_paged_lines(f"{base}/log", client)


async def fetch_full_job_listing(client, session_id, job_id):
    base = f"/compute/sessions/{session_id}/jobs/{job_id}"
    text = await _get_text(f"{base}/listing", client)
    if text is not None:
        return text
    return await _get_paged_lines(f"{base}/listing", client)


async def fetch_full_session_log(client, session_id):
    # Entire session log (useful if you want everything the session produced)
    text = await _get_text(f"/compute/sessions/{session_id}/log", client)
    if text is not None:
        return text
    return await _get_paged_lines(f"/compute/sessions/{session_id}/log", client)


async def get_context_id(client, context_name):
    url = f"{VIYA_ENDPOINT}/compute/contexts?name={context_name}"
    resp = await client.get(url)
    coll = resp.json()
    items = coll.get("items", [])
    if not items:
        raise RuntimeError(f"Compute context not found: {context_name}")
    return items[0]["id"]


async def create_session(client, context_id, name="py-parallel"):
    url = f"{VIYA_ENDPOINT}/compute/contexts/{context_id}/sessions"
    resp = await client.post(url, json={"name": name})
    return resp.json()["id"]


async def submit_job(client, session_id, code):
    body = {"code": code.splitlines()}
    url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs"
    resp = await client.post(url, json=body)
    job = resp.json()
    return job["id"]


async def wait_job(client, session_id, job_id, poll=2):
    while True:
        state_url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs/{job_id}/state"
        resp = await client.get(state_url)
        state = resp.text.strip()
        if state in ("completed", "error", "warning", "canceled"):
            # Fetch log
            log_url = f"{VIYA_ENDPOINT}/compute/sessions/{session_id}/jobs/{job_id}/log"
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


async def run_one_snippet(snippet_data, snippet_id, token):
    code = snippet_data

    logger.info(f"Creating session with token (length: {len(token)})")

    async with _make_client(token) as client:
        ctx_id = await get_context_id(client, CONTEXT_NAME)
        sid = await create_session(client, ctx_id, name="py-parallel")
        logger.info(f"Session created: {sid}")
        try:
            jid = await submit_job(client, sid, code)
            logger.info(f"Job submitted: {jid}")
            result = await wait_job(client, sid, jid)
            logger.info(f"Job completed: {result[0]}")
            return (snippet_id, *result)
        except Exception as e:
            logger.error(f"Error executing SAS job: {str(e)}")
            raise e
        finally:
            try:
                delete_url = f"{VIYA_ENDPOINT}/compute/sessions/{sid}"
                await client.delete(delete_url)
                logger.info(f"Session {sid} deleted successfully")
            except Exception as e:
                logger.error(f"Failed to delete session {sid}: {str(e)}")
                raise e


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


async def list_iot_analyses(token: str) -> dict:
    """Lists all defined SAS Analytics for IoT analyses."""
    async with _make_client(token) as client:
        return await _get_json("/iotAnalysis/analyses", client,
                               accept="application/vnd.sas.collection+json")


async def get_iot_analysis(analysis_id: str, token: str) -> dict:
    """Retrieves the full definition of an IoT analysis."""
    async with _make_client(token) as client:
        return await _get_json(f"/iotAnalysis/analyses/{analysis_id}", client,
                               accept="application/vnd.sas.iot.analysis+json")


async def create_iot_analysis(name: str, model_name: str, data_selection_id: str, token: str, folder_id: str = None) -> dict:
    """Creates a new IoT analysis instance."""
    async with _make_client(token) as client:
        body = {
            "name": name,
            "modelName": model_name,
            "dataSelectionId": data_selection_id
        }
        if folder_id:
            body["folderID"] = folder_id
        
        # Wrapped in a collection for this particular endpoint
        collection_body = {
            "name": "analysis",
            "items": [body]
        }
        
        return await _post_json("/iotAnalysis/analyses", client,
                                body=collection_body,
                                accept="application/json")


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
                    raise RuntimeError(f"No steps found for analysis {analysis_id}")
                step_id = steps[0]["id"]
                return await _post_json(f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs", client,
                                        body={},
                                        accept="application/json")
            raise e


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
        # Note: Depending on context, job_id might be under /jobExecution/jobs or /iotAnalysis/analyses/{id}/jobs/{job_id}
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
