# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""SAS Analytics for IoT / FQA tools."""

import asyncio
import contextlib
import json
import re
import time
from collections.abc import Awaitable, Callable
from typing import Any

import httpx
from cachetools import TTLCache
from fastmcp import Context, FastMCP

from ..config import AIOT_LAUNCH_KEY_DIM, AIOT_LAUNCH_TRANSPOSE, VIYA_ENDPOINT
from ..viya_client import logger, make_client
from ..viya_utils import _token_user_key, run_one_snippet
from ._common import make_session_helpers

data_selection_cache = TTLCache(maxsize=100, ttl=60)

_SAS_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]{0,63}$")
_SAFE_PATH_RE = re.compile(r"^[A-Za-z0-9_./:-]+$")


def _validate_sas_identifier(value: str, label: str = "identifier") -> str:
    """Validate that *value* is a safe SAS/CAS identifier with no quotes or semicolons."""
    cleaned = (value or "").strip()
    if not cleaned or not _SAS_IDENTIFIER_RE.match(cleaned):
        raise ValueError(f"Invalid SAS {label}: {value!r}")
    return cleaned


def _validate_safe_path(value: str) -> str:
    """Validate that a filesystem path contains no quotes or injection characters."""
    cleaned = (value or "").strip()
    if not cleaned or ".." in cleaned or not _SAFE_PATH_RE.match(cleaned):
        raise ValueError(f"Invalid or unsafe path: {value!r}")
    return cleaned


_SORT_FIELD_ALIASES: dict[str, tuple[str, ...]] = {
    "score": ("score", "Index", "INDEX"),
    "index": ("Index", "score", "INDEX"),
    "cost_score": ("cost_score", "Index_TOTAL_EVENT_AMT", "INDEX_TOTAL_EVENT_AMT"),
    "index_total_event_amt": ("Index_TOTAL_EVENT_AMT", "cost_score", "INDEX_TOTAL_EVENT_AMT"),
    "acceleration": ("Acceleration", "acceleration", "Acceleration_AP", "acceleration_ap"),
    "acceleration_ap": ("Acceleration_AP", "acceleration_ap", "Acceleration", "acceleration"),
    "events": ("Events", "events", "EVENTS"),
}


def _extract_field_case_insensitive(item: dict[str, Any], field_name: str) -> Any:
    """Retrieve a field from *item* supporting FQA aliases and case-insensitive matching."""
    if not isinstance(item, dict) or not field_name:
        return None
    if field_name in item and item[field_name] is not None:
        return item[field_name]
    lower_target = field_name.lower()
    for alias in _SORT_FIELD_ALIASES.get(lower_target, ()):
        if alias in item and item[alias] is not None:
            return item[alias]
    for key, val in item.items():
        if key.lower() == lower_target and val is not None:
            return val
    return None


def _sort_items(
    items: list[dict[str, Any]],
    sort_by: str | None = None,
    sort_order: str = "desc",
) -> list[dict[str, Any]]:
    """Sort *items* by *sort_by* (numeric-aware, case-insensitive) with missing values placed last."""
    if not items or not sort_by:
        return list(items)
    reverse = (sort_order or "desc").strip().lower() != "asc"
    present: list[tuple[tuple[int, Any], int, dict[str, Any]]] = []
    missing: list[dict[str, Any]] = []
    for idx, item in enumerate(items):
        val = _extract_field_case_insensitive(item, sort_by)
        if val is None or val == "":
            missing.append(item)
            continue
        if isinstance(val, (int, float)) and not isinstance(val, bool):
            key = (0, float(val))
        else:
            try:
                key = (0, float(str(val)))
            except (ValueError, TypeError):
                key = (1, str(val).lower())
        present.append((key, idx, item))
    present.sort(key=lambda entry: entry[0], reverse=reverse)
    return [entry[2] for entry in present] + missing


def _paginate_sorted_items(
    items: list[dict[str, Any]],
    start: int = 0,
    limit: int = 10,
    sort_by: str | None = None,
    sort_order: str = "desc",
    item_label: str = "items",
) -> dict[str, Any]:
    """Sort *items* and slice to top *limit* (default 10) with pagination metadata."""
    sorted_items = _sort_items(items, sort_by=sort_by, sort_order=sort_order)
    total = len(sorted_items)
    safe_start = max(0, int(start or 0))
    safe_limit = max(1, int(limit if limit is not None else 10))
    sliced = sorted_items[safe_start : safe_start + safe_limit]
    next_start = safe_start + len(sliced)
    remaining_count = max(0, total - next_start)
    has_more = remaining_count > 0
    if has_more:
        pagination_hint = (
            f"Showing {len(sliced)} of {total} {item_label} "
            f"(start={safe_start}, limit={safe_limit}, sort_by={sort_by or 'default'}, sort_order={sort_order}). "
            f"{remaining_count} more available — pass start={next_start} "
            "(or increase limit) to show the rest of the list."
        )
    else:
        pagination_hint = f"Showing all {len(sliced)} of {total} {item_label}."
    return {
        "items": sliced,
        "total": total,
        "count": total,
        "returned_count": len(sliced),
        "start": safe_start,
        "limit": safe_limit,
        "sort_by": sort_by,
        "sort_order": (sort_order or "desc").lower(),
        "has_more": has_more,
        "remaining_count": remaining_count,
        "next_start": next_start if has_more else None,
        "pagination_hint": pagination_hint,
    }


def _annotate_fqa_alert(alert: dict[str, Any]) -> dict[str, Any]:
    """Normalize score/cost_score aliases and attach FQA Phase 0 triage hints to an alert record."""
    enriched = dict(alert)
    score_val = _extract_field_case_insensitive(enriched, "score")
    if score_val is not None and "score" not in enriched:
        enriched["score"] = score_val
    cost_val = _extract_field_case_insensitive(enriched, "cost_score")
    if cost_val is not None and "cost_score" not in enriched:
        enriched["cost_score"] = cost_val

    alert_type_upper = str(_extract_field_case_insensitive(enriched, "alert_type") or "").upper()
    acc_ap = _extract_field_case_insensitive(enriched, "Acceleration_AP")
    acc_tis = _extract_field_case_insensitive(enriched, "Acceleration")
    use_ap = "PROD" in alert_type_upper or "BUILD" in alert_type_upper or acc_ap is not None
    primary_beta_raw = acc_ap if use_ap else acc_tis
    if primary_beta_raw is None:
        primary_beta_raw = acc_tis

    beta_val: float | None = None
    if primary_beta_raw is not None and primary_beta_raw != "":
        try:
            beta_val = float(primary_beta_raw)
        except (ValueError, TypeError):
            beta_val = None

    if beta_val is None or beta_val <= 0:
        failure_mode_hint = "unknown"
    elif beta_val < 0.85:
        failure_mode_hint = "infant_mortality_or_production_batch"
    elif beta_val <= 1.15:
        failure_mode_hint = "random_constant_hazard"
    else:
        failure_mode_hint = "wear_out_aging_accumulation"

    events_raw = _extract_field_case_insensitive(enriched, "Events")
    events_val: float | None = None
    if events_raw is not None and events_raw != "":
        try:
            events_val = float(events_raw)
        except (ValueError, TypeError):
            events_val = None

    enriched["weibull_beta"] = beta_val
    enriched["failure_mode_hint"] = failure_mode_hint
    enriched["is_small_n"] = bool(events_val is not None and events_val < 5)
    return enriched



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



async def list_data_selections(token: str, filter_query: str = None, start: int = 0, limit: int = 10) -> dict:  # pyright: ignore
    """Lists available SAS Analytics for IoT data selections with TTL caching."""
    cache_key = (_token_user_key(token), filter_query, start, limit)
    if cache_key in data_selection_cache:
        logger.info("Returning cached results for data selection list: %s", cache_key)
        return data_selection_cache[cache_key]  # pyright: ignore

    params = {"start": start, "limit": limit}
    if filter_query:
        params["filter"] = filter_query  # pyright: ignore
    
    async with make_client(token) as client:
        result = await _get_json("/dataSelection/dataSelections", client, 
                                 params=params, 
                                 accept="application/vnd.sas.collection+json")
        data_selection_cache[cache_key] = result
        return result


async def get_data_selection(selection_id: str, token: str) -> dict:
    """Retrieves detailed information for a specific SAS AIoT data selection."""
    async with make_client(token) as client:
        return await _get_json(f"/dataSelection/dataSelections/{selection_id}", client,
                               accept="application/vnd.sas.data.selection+json")


async def update_data_selection(selection_id: str, selection_data: dict, token: str) -> dict:
    """Updates a specific SAS AIoT data selection."""
    async with make_client(token) as client:
        # Fetch current state to get ETag for optimistic concurrency
        url = f"/dataSelection/dataSelections/{selection_id}"
        resp = await client.get(f"{VIYA_ENDPOINT}{url}", 
                                headers={"Accept": "application/vnd.sas.data.selection+json"})
        resp.raise_for_status()
        etag = resp.headers.get("ETag")
        
        result = await _put_json(url, client, body=selection_data,
                                 accept="application/vnd.sas.data.selection+json",
                                 if_match=etag)
        data_selection_cache.clear()
        return result


async def delete_data_selection(selection_id: str, token: str) -> None:
    """Deletes a SAS AIoT data selection."""
    async with make_client(token) as client:
        await _delete_resource(f"/dataSelection/dataSelections/{selection_id}", client)
        data_selection_cache.clear()


async def launch_data_selection(selection_id: str, token: str, table_name: str | None = None,
                                launch_key_dim: str | None = None,
                                launch_app_name: str = "CAS",
                                transpose_flag: bool = AIOT_LAUNCH_TRANSPOSE,
                                launch_columns: list[dict] | None = None,
                                launch_column_tables: list[str] | None = None) -> dict:
    """Triggers a launch job for a specific data selection.

    ``launch_key_dim`` falls back to AIOT_LAUNCH_KEY_DIM rather than being
    omitted — the service rejects a launch that names no key dimension.
    The service also rejects a launch without columns (errorCode 76010,
    "Specify the columns for the data selection launch."). Each column is
    ``{"columnName", "columnTableName"}`` plus optional labels;
    ``launch_column_tables`` defaults to the columns' tables.
    """
    columns = list(launch_columns or [])
    tables = list(launch_column_tables) if launch_column_tables else sorted(
        {c["columnTableName"] for c in columns if c.get("columnTableName")})
    body: dict[str, Any] = {
        "tableName": table_name or f"DS_{selection_id.replace('-', '_')[:24]}",
        "launchAppName": launch_app_name,
        # Sent as 0/1, the form the documented createLaunch request uses; the
        # service reports it back as a boolean. bool is an int, so a caller
        # passing either spelling lands on the same wire value.
        "transposeFlag": int(transpose_flag),
        "launchColumnTables": tables,
        "launchColumns": columns,
    }
    key_dim = launch_key_dim or AIOT_LAUNCH_KEY_DIM
    if key_dim:
        body["launchKeyDim"] = key_dim
    async with make_client(token) as client:
        return await _post_json(f"/dataSelection/dataSelections/{selection_id}/launches", client,
                                body=body,
                                accept="application/vnd.sas.data.selection.launch+json")


async def copy_data_selection(selection_id: str, new_name: str, token: str, new_description: str = "", creation_type: str | None = None) -> dict:
    """Copies a specific SAS AIoT data selection."""
    async with make_client(token) as client:
        body = {"name": new_name, "description": new_description}
        if creation_type:
            body["creationType"] = creation_type
        result = await _post_json(f"/dataSelection/dataSelections/{selection_id}/copy", client,
                                  body=body,
                                  accept="application/vnd.sas.data.selection+json")
        data_selection_cache.clear()
        return result


async def copy_data_selections(selection_ids: list[str], token: str) -> dict:
    """Copies multiple SAS AIoT data selections."""
    async with make_client(token) as client:
        body = {"resources": selection_ids}
        result = await _post_json("/dataSelection/dataSelectionActions/copies", client,
                                  body=body,
                                  accept="application/json")
        data_selection_cache.clear()
        return result


async def list_iot_projects(token: str) -> dict:
    """Lists project instances from the IoT analysis service."""
    async with make_client(token) as client:
        return await _get_json("/iotAnalysis/projects", client,
                               accept="application/vnd.sas.collection+json")


async def list_iot_analyses(token: str, start: int = None, limit: int = None) -> dict:  # pyright: ignore
    """Lists all defined SAS Analytics for IoT analyses."""
    params = {}
    if start is not None:
        params["start"] = start
    if limit is not None:
        params["limit"] = limit
    async with make_client(token) as client:
        return await _get_json("/iotAnalysis/analyses", client,
                               params=params or None,
                               accept="application/vnd.sas.collection+json")


async def get_iot_analysis(analysis_id: str, token: str) -> dict:
    """Retrieves the full definition of an IoT analysis."""
    async with make_client(token) as client:
        return await _get_json(f"/iotAnalysis/analyses/{analysis_id}", client,
                               accept="application/vnd.sas.iot.analysis+json")


async def create_iot_analysis(
    name: str,
    model_name: str,
    data_selection_id: str,
    token: str,
    folder_id: str = None,  # pyright: ignore
    parent_instance_id: str = None,  # pyright: ignore
    parent_step_id: str = None,  # pyright: ignore
    subset_group_name: str = None,  # pyright: ignore
    filter_criteria: list = None  # pyright: ignore
) -> dict:
    """Creates a new IoT analysis instance."""
    async with make_client(token) as client:
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
            body["filterCriteria"] = filter_criteria  # pyright: ignore
        
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
    folder_id: str = None,  # pyright: ignore
    parameter_updates: dict = None,  # pyright: ignore
    wait_for_completion: bool = True,
    parent_instance_id: str = None,  # pyright: ignore
    parent_step_id: str = None,  # pyright: ignore
    subset_group_name: str = None,  # pyright: ignore
    filter_criteria: list = None  # pyright: ignore
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

    async with make_client(token) as client:
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
    async with make_client(token) as client:
        await _delete_resource(f"/iotAnalysis/analyses/{analysis_id}", client)


async def run_iot_analysis(analysis_id: str, token: str) -> dict:
    """Submits a job to run a specific IoT analysis."""
    async with make_client(token) as client:
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
    async with make_client(token) as client:
        body = {
            "version": 1,
            "resources": analysis_ids
        }
        return await _post_json("/iotAnalysis/analysisActions/copies", client,
                                body=body,
                                accept="application/json")


async def get_iot_analysis_job(analysis_id: str, job_id: str, token: str) -> dict:
    """Retrieves the status and results of a specific IoT analysis job."""
    async with make_client(token) as client:
        # Note: Depending on context, job_id might be under /jobExecution/jobs
        # or /iotAnalysis/analyses/{id}/jobs/{job_id}.
        # The tool implementation currently assumes the latter.
        return await _get_json(f"/iotAnalysis/analyses/{analysis_id}/jobs/{job_id}", client,
                               accept="application/vnd.sas.iot.analysis.job+json")


async def list_iot_models(token: str) -> dict:
    """Lists all registered models in SAS Analytics for IoT."""
    async with make_client(token) as client:
        return await _get_json("/iotAnalysisModels/models", client,
                               accept="application/vnd.sas.collection+json")


async def get_iot_model(model_name: str, token: str) -> dict:
    """Retrieves metadata for a specific AIoT model."""
    async with make_client(token) as client:
        return await _get_json(f"/iotAnalysisModels/models/{model_name}", client,
                               accept="application/vnd.sas.iot.analysis.model.detail+json")


# ---------------------------------------------------------------------------
# CAS Management Service Helpers
# ---------------------------------------------------------------------------

async def get_cas_summary_statistics(server_id: str, caslib_name: str, table_name: str, token: str) -> dict:
    """Retrieves summary statistics for a CAS table."""
    async with make_client(token) as client:
        url = f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}/summaryStatistics"
        return await _get_json(url, client, accept="application/vnd.sas.collection+json")


# ---------------------------------------------------------------------------
# High-Level Workflow Orchestration
# ---------------------------------------------------------------------------

_TERMINAL_JOB_STATES = {
    "completed",
    "failed",
    "cancelled",
    "canceled",
    "error",
    "timedout",
    "timed_out",
    "warning",
}


async def poll_job(
    job_url: str, token: str, poll_interval: float = 1.0, timeout: float = 3600.0
) -> dict:
    """Polls a job status until it reaches a terminal state or *timeout* elapses."""
    deadline = time.monotonic() + timeout
    async with make_client(token) as client:
        while True:
            resp = await client.get(f"{VIYA_ENDPOINT}{job_url}", headers={"Accept": "application/json"})
            resp.raise_for_status()
            status_data = resp.json()
            state = (status_data.get("state") or status_data.get("status") or "").lower()
            if state in _TERMINAL_JOB_STATES:
                return status_data
            if time.monotonic() >= deadline:
                raise TimeoutError(f"Polling job {job_url} timed out after {timeout}s (last state: {state!r})")
            await asyncio.sleep(poll_interval)
            # Exponential backoff up to 10s
            poll_interval = min(poll_interval * 1.5, 10.0)


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


async def launch_data_selection_and_wait(selection_id: str, token: str, **launch_kwargs) -> dict:
    """Launches a data selection and waits for completion."""
    launch_result = await launch_data_selection(selection_id, token, **launch_kwargs)
    # The launch resource's own id differs from the id of the job executing it.
    job_url = f"/jobExecution/jobs/{launch_result['jobId']}"
    return await poll_job(job_url, token)


async def list_folders_and_projects(token: str, folder_id: str = None) -> dict:  # pyright: ignore
    """Lists folders and projects under a specific folder (or root if not specified)."""
    async with make_client(token) as client:
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


async def create_folder(name: str, token: str, parent_folder_id: str = "@myFolder", description: str = None) -> dict:  # pyright: ignore
    """Creates a new folder under a parent folder."""
    async with make_client(token) as client:
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


async def create_project(name: str, token: str, folder_id: str = "@myFolder", description: str = None) -> dict:  # pyright: ignore
    """Creates a new IoT project under a folder."""
    async with make_client(token) as client:
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
    async with make_client(token) as client:
        await _delete_resource(f"/folders/folders/{folder_id}", client)


async def delete_project(project_id: str, token: str) -> None:
    """Deletes an IoT project by ID."""
    async with make_client(token) as client:
        await _delete_resource(f"/iotAnalysis/projects/{project_id}", client)




def register(
    mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]
) -> None:
    """Register IoT / FQA tools."""
    viya_session, _ = make_session_helpers(get_token)

    

    @mcp.tool()
    async def get_iot_analysis_step_log_tool(analysis_id: str, step_id: str, ctx: Context) -> str:
        """
        Retrieves the SAS Compute log for a specific step's latest job execution.
        Crucial for debugging CAF analyses that fail during execution.
        """
        logger.info("--- TOOL USED: get_iot_analysis_step_log_tool (%s, %s) ---", analysis_id, step_id)
        token = await get_token(ctx)
        
        async with make_client(token) as client:
            step_resp = await _get_json(f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}", client, accept="application/json")
            jobs_link = next((l for l in step_resp.get("links", []) if l["rel"] == "job"), None)
            if not jobs_link:
                return "No job link found for this step. It may not have run yet."
                
            job_resp = await _get_json(jobs_link["uri"], client, accept="application/json")
            log_link = next((l for l in job_resp.get("links", []) if l["rel"] == "log"), None)
            if not log_link:
                return f"No log link found for job."
                
            log_file = await _get_json(log_link["uri"], client, accept="application/json")
            content_link = next((l for l in log_file.get("links", []) if l["rel"] == "content"), None)
            if not content_link:
                return "No content link found in the log file object."
                
            res = await client.get(f"{VIYA_ENDPOINT}{content_link['uri']}", headers={"Accept": "text/plain", "Authorization": f"Bearer {token}"})
            res.raise_for_status()
            text = res.text
            if len(text) > 100000:
                text = "...(truncated)...\n" + text[-100000:]
            return text

    @mcp.tool()
    async def update_analysis_step_parameters_tool(analysis_id: str, step_id: str, parameters: dict, ctx: Context) -> dict:
        """
        Updates specific input parameters for a single step of an Analysis. 
        Pass a dictionary of parameterName: parameterValue.
        """
        logger.info("--- TOOL USED: update_analysis_step_parameters_tool (%s, %s) ---", analysis_id, step_id)
        token = await get_token(ctx)
        
        async with make_client(token) as client:
            target = await _get_json(f"/iotAnalysis/analyses/{analysis_id}", client, accept="application/vnd.sas.iot.analysis+json")
            step_found = False
            for s in target.get("steps", []):
                if s.get("id") == step_id or s.get("modelStepId") == step_id:
                    step_found = True
                    for p in s.get("inputParameters", []):
                        p_name = p.get("parameterName")
                        if p_name in parameters:
                            p["parameterValue"] = str(parameters[p_name])
                    break
            if not step_found:
                raise ValueError(f"Step {step_id} not found in analysis {analysis_id}")
                
            res = await client.put(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                json=target,
                headers={"Accept": "application/vnd.sas.iot.analysis+json", "Content-Type": "application/vnd.sas.iot.analysis+json", "Authorization": f"Bearer {token}"}
            )
            res.raise_for_status()
            return res.json()

    @mcp.tool()
    async def run_analysis_step_and_wait_tool(analysis_id: str, step_id: str, ctx: Context) -> dict:
        """
        Executes a specific step of an analysis and waits for its job to complete.
        """
        logger.info("--- TOOL USED: run_analysis_step_and_wait_tool (%s, %s) ---", analysis_id, step_id)
        token = await get_token(ctx)
        
        async with make_client(token) as client:
            job_url = f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs"
            run_res = await _post_json(job_url, client, body={}, accept="application/json")
            job_id = run_res.get("id")
            if not job_id:
                raise RuntimeError("Failed to obtain a job ID when launching step.")
            job_exec_url = f"/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs/{job_id}"
            return await poll_job(job_exec_url, token, poll_interval=2.0)



    @mcp.tool()
    async def list_data_selections_tool(
        ctx: Context,
        filter_query: str = None,  # pyright: ignore
        start: int = 0,
        limit: int = 10,
        owner: str = None,  # pyright: ignore
        owner_display_name: str = None,  # pyright: ignore
        created_by: str = None,  # pyright: ignore
        name: str = None,  # pyright: ignore
        category: str = None,  # pyright: ignore
        creation_type: str = None,  # pyright: ignore
        attribute_filters: dict = None,  # pyright: ignore
        sort_by: str = None,  # pyright: ignore
        sort_order: str = "desc",
    ) -> dict:
        """
        Lists available SAS Analytics for IoT data selections (returns top 10 by default).
        Supports filtering and sorting by any attribute (e.g., creationTimeStamp, name, owner).

        Args:
            filter_query (str): Optional service-side filter string (e.g., "eq(createdBy,'Martin Schuetz')")
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            owner (str): Optional case-insensitive substring filter for owner username (e.g., 'germsz')
            owner_display_name (str): Optional case-insensitive substring filter for owner display name
                                      (e.g., 'Schuetz, Martin')
            created_by (str): Optional case-insensitive substring filter for creator name (e.g., 'Martin')
            name (str): Optional case-insensitive substring filter for data selection name (e.g., 'Chiller')
            category (str): Optional case-insensitive substring filter for category (e.g., 'SIMPLE')
            creation_type (str): Optional case-insensitive substring filter for creation type
                                 (e.g., 'DEFAULT')
            attribute_filters (dict): Optional dictionary mapping any attribute name to target value
                                      for dynamic filtering
            sort_by (str): Optional attribute name to sort by before slicing (e.g., 'creationTimeStamp', 'name')
            sort_order (str): Sort direction: 'desc' (default) or 'asc'
        """
        logger.info("--- TOOL USED: list_data_selections (filter: %s) ---", filter_query)
        token = await get_token(ctx)

        has_local_filters = any(
            [owner, owner_display_name, created_by, name, category, creation_type, attribute_filters, sort_by]
        )
        if not has_local_filters:
            raw_data = await list_data_selections(
                token,
                filter_query=filter_query,
                start=start,
                limit=limit,
            )
            paginated_items = raw_data.get("items", [])
            total_filtered_count = raw_data.get("count", len(paginated_items))
        else:
            # To support local filtering/sorting across the entire collection, fetch all items in batches
            all_items = []
            current_start = 0
            fetch_limit = 100

            while True:
                raw_data = await list_data_selections(
                    token,
                    filter_query=filter_query,
                    start=current_start,
                    limit=fetch_limit
                )
                items = raw_data.get("items", [])
                all_items.extend(items)
                
                total_count = raw_data.get("count", 0)
                if len(items) < fetch_limit or len(all_items) >= total_count:
                    break
                current_start += fetch_limit

            # Apply client-side attribute filtering
            filtered_items = all_items

            def matches_filter(item_val, filter_val) -> bool:
                if item_val is None:
                    return False
                return str(filter_val).lower() in str(item_val).lower()

            if owner:
                filtered_items = [item for item in filtered_items if matches_filter(item.get("owner"), owner)]
            if owner_display_name:
                filtered_items = [
                    item for item in filtered_items
                    if matches_filter(item.get("ownerDisplayName"), owner_display_name)
                ]
            if created_by:
                filtered_items = [item for item in filtered_items if matches_filter(item.get("createdBy"), created_by)]
            if name:
                filtered_items = [item for item in filtered_items if matches_filter(item.get("name"), name)]
            if category:
                filtered_items = [item for item in filtered_items if matches_filter(item.get("category"), category)]
            if creation_type:
                filtered_items = [
                    item for item in filtered_items
                    if matches_filter(item.get("creationType"), creation_type)
                ]

            if attribute_filters:
                for attr, val in attribute_filters.items():
                    filtered_items = [item for item in filtered_items if matches_filter(item.get(attr), val)]

            if sort_by:
                filtered_items = _sort_items(filtered_items, sort_by=sort_by, sort_order=sort_order)

            total_filtered_count = len(filtered_items)
            paginated_items = filtered_items[start : start + limit]

        # Prune response but include key attributes for transparency
        pruned_items = [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "createdBy": item.get("createdBy"),
                "creationTimeStamp": item.get("creationTimeStamp"),
                "owner": item.get("owner"),
                "ownerDisplayName": item.get("ownerDisplayName"),
                "category": item.get("category"),
                "creationType": item.get("creationType"),
                "description": item.get("description"),
            }
            for item in paginated_items
        ]

        next_start = start + len(pruned_items)
        remaining_count = max(0, total_filtered_count - next_start)
        has_more = remaining_count > 0
        pagination_hint = (
            f"Showing {len(pruned_items)} of {total_filtered_count} data selections "
            f"(start={start}, limit={limit}, sort_by={sort_by or 'default'}, sort_order={sort_order}). "
            f"{remaining_count} more available — pass start={next_start} "
            "(or increase limit) to show the rest of the list."
            if has_more
            else f"Showing all {len(pruned_items)} of {total_filtered_count} data selections."
        )

        return {
            "count": total_filtered_count,
            "total": total_filtered_count,
            "returned_count": len(pruned_items),
            "items": pruned_items,
            "limit": limit,
            "start": start,
            "sort_by": sort_by,
            "sort_order": (sort_order or "desc").lower(),
            "has_more": has_more,
            "remaining_count": remaining_count,
            "next_start": next_start if has_more else None,
            "pagination_hint": pagination_hint,
        }

    @mcp.tool()
    async def get_data_selection_details(selection_id: str, ctx: Context) -> dict:
        """
        Retrieves detailed information and metadata for a specific SAS AIoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info("--- TOOL USED: get_data_selection_details (%s) ---", selection_id)
        token = await get_token(ctx)
        return await get_data_selection(selection_id, token)

    @mcp.tool()
    async def update_data_selection_tool(selection_id: str, selection_data: dict, ctx: Context) -> dict:
        """
        Updates a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
            selection_data (dict): The complete data selection definition to update.
        """
        logger.info("--- TOOL USED: update_data_selection (%s) ---", selection_id)
        token = await get_token(ctx)
        return await update_data_selection(selection_id, selection_data, token)

    @mcp.tool()
    async def delete_data_selection_tool(selection_id: str, ctx: Context) -> str:
        """
        Deletes a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info("--- TOOL USED: delete_data_selection (%s) ---", selection_id)
        token = await get_token(ctx)
        await delete_data_selection(selection_id, token)
        return f"Data selection {selection_id} deleted successfully."

    @mcp.tool()
    async def set_data_selection_date_range_tool(selection_id: str, start_date: str, 
                                               end_date: str, ctx: Context) -> dict:
        """
        Updates the Measure Date Time filter for a data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
            start_date (str): The start date in ISO 8601 format (e.g., '2024-07-01T00:00:00Z').
            end_date (str): The end date in ISO 8601 format (e.g., '2024-09-30T23:59:59Z').
        """
        logger.info("--- TOOL USED: set_data_selection_date_range (%s) ---", selection_id)
        token = await get_token(ctx)
        return await set_data_selection_date_range(selection_id, start_date, end_date, token)

    @mcp.tool()
    async def launch_data_selection_tool(selection_id: str, ctx: Context,
                                         table_name: str | None = None,
                                         launch_key_dim: str | None = None,
                                         transpose_flag: bool = AIOT_LAUNCH_TRANSPOSE,
                                         launch_columns: list[dict] | None = None,
                                         launch_column_tables: list[str] | None = None) -> dict:
        """
        Triggers a launch job for a specific data selection, loading the data into CAS for analysis.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
            table_name (str, optional): Name for the resulting CAS table. Defaults to a name derived from selection_id.
            launch_key_dim (str, optional): Key dimension for the launch, e.g. 'ASSET', 'PRODUCT' or 'BATCH'.
                Defaults to this deployment's AIOT_LAUNCH_KEY_DIM.
            transpose_flag (bool, optional): Whether to transpose the launched table.
            launch_columns (list[dict], optional): Columns to launch, each
                {"columnName": ..., "columnTableName": ...} (labels optional). Viya rejects a
                launch without columns (errorCode 76010).
            launch_column_tables (list[str], optional): Tables of the columns, e.g.
                ["CLAIM", "PART", "PRODUCT"]. Defaults to the tables named in launch_columns.
        """
        logger.info("--- TOOL USED: launch_data_selection (%s) ---", selection_id)
        token = await get_token(ctx)
        return await launch_data_selection(selection_id, token, table_name=table_name,
                                           launch_key_dim=launch_key_dim,
                                           transpose_flag=transpose_flag,
                                           launch_columns=launch_columns,
                                           launch_column_tables=launch_column_tables)

    @mcp.tool()
    async def launch_data_selection_and_wait_tool(selection_id: str, ctx: Context,
                                                  table_name: str | None = None,
                                                  launch_key_dim: str | None = None,
                                                  transpose_flag: bool = AIOT_LAUNCH_TRANSPOSE,
                                                  launch_columns: list[dict] | None = None,
                                                  launch_column_tables: list[str] | None = None) -> dict:
        """
        Launches a data selection and waits for the job to complete.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
            table_name (str, optional): Name for the resulting CAS table. Defaults to a name derived from selection_id.
            launch_key_dim (str, optional): Key dimension for the launch, e.g. 'ASSET', 'PRODUCT' or 'BATCH'.
                Defaults to this deployment's AIOT_LAUNCH_KEY_DIM.
            transpose_flag (bool, optional): Whether to transpose the launched table.
            launch_columns (list[dict], optional): Columns to launch, each
                {"columnName": ..., "columnTableName": ...} (labels optional). Viya rejects a
                launch without columns (errorCode 76010).
            launch_column_tables (list[str], optional): Tables of the columns, e.g.
                ["CLAIM", "PART", "PRODUCT"]. Defaults to the tables named in launch_columns.
        """
        logger.info("--- TOOL USED: launch_data_selection_and_wait (%s) ---", selection_id)
        token = await get_token(ctx)
        return await launch_data_selection_and_wait(selection_id, token, table_name=table_name,
                                                    launch_key_dim=launch_key_dim,
                                                    transpose_flag=transpose_flag,
                                                    launch_columns=launch_columns,
                                                    launch_column_tables=launch_column_tables)

    @mcp.tool()
    async def copy_data_selection_tool(selection_id: str, new_name: str, 
                                       ctx: Context, new_description: str = "", creation_type: str | None = None) -> dict:
        """
        Copies a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection to copy.
            new_name (str): The name for the new data selection.
            new_description (str): Optional description for the new data selection.
            creation_type (str, optional): Override the creationType (e.g. 'EIENTERPRISE' for Emerging Issues).
        """
        logger.info("--- TOOL USED: copy_data_selection (%s -> %s) ---", selection_id, new_name)
        token = await get_token(ctx)
        return await copy_data_selection(selection_id, new_name, token, new_description, creation_type)

    @mcp.tool()
    async def copy_data_selections_tool(selection_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT data selections.

        Args:
            selection_ids (list[str]): List of data selection identifiers to copy.
        """
        logger.info("--- TOOL USED: copy_data_selections (%s items) ---", len(selection_ids))
        token = await get_token(ctx)
        return await copy_data_selections(selection_ids, token)

    @mcp.tool()
    async def list_iot_projects_tool(ctx: Context) -> dict:
        """
        Lists all defined project instances in SAS Analytics for IoT.
        """
        logger.info("--- TOOL USED: list_iot_projects ---")
        token = await get_token(ctx)
        return await list_iot_projects(token)

    @mcp.tool()
    async def list_iot_analyses_tool(ctx: Context) -> dict:
        """
        Lists all defined SAS Analytics for IoT analyses.
        """
        logger.info("--- TOOL USED: list_iot_analyses ---")
        token = await get_token(ctx)
        return await list_iot_analyses(token)

    @mcp.tool()
    async def get_iot_analysis_details_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Retrieves the full definition of an IoT analysis, including steps and parameters.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info("--- TOOL USED: get_iot_analysis_details (%s) ---", analysis_id)
        token = await get_token(ctx)
        return await get_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def create_iot_analysis_tool(
        name: str,
        model_name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_instance_id: str = None,  # pyright: ignore
        parent_step_id: str = None,  # pyright: ignore
        subset_group_name: str = None,  # pyright: ignore
        filter_criteria: list = None  # pyright: ignore
    ) -> dict:
        """
        Creates a new IoT analysis instance.

        Args:
            name (str): Name for the new analysis.
            model_name (str): Name of the analysis model (e.g., 'EXPLORATION_ASSET').
            data_selection_id (str): ID of the data selection to associate.
            folder_id (str): Optional ID of the project folder to create the analysis in.
            parent_instance_id (str): Optional parent analysis instance ID for hierarchical linking.
            parent_step_id (str): Optional parent analysis step ID for hierarchical linking.
            subset_group_name (str): Optional subset group name (required if parent linking is used).
            filter_criteria (list): Optional filter criteria list (required if parent linking is used).
        """
        logger.info("--- TOOL USED: create_iot_analysis (%s) ---", name)
        token = await get_token(ctx)
        return await create_iot_analysis(
            name, model_name, data_selection_id, token, folder_id,
            parent_instance_id, parent_step_id, subset_group_name, filter_criteria
        )

    @mcp.tool()
    async def delete_iot_analysis_tool(analysis_id: str, ctx: Context) -> str:
        """
        Deletes a specific SAS Analytics for IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info("--- TOOL USED: delete_iot_analysis (%s) ---", analysis_id)
        token = await get_token(ctx)
        await delete_iot_analysis(analysis_id, token)
        return f"Analysis {analysis_id} deleted successfully."

    @mcp.tool()
    async def run_iot_analysis_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Submits a job to run a specific IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis to run.
        """
        logger.info("--- TOOL USED: run_iot_analysis (%s) ---", analysis_id)
        token = await get_token(ctx)
        return await run_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def run_iot_analysis_and_wait_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Runs a specific IoT analysis and waits for the job to complete.

        Args:
            analysis_id (str): The unique identifier of the analysis to run.
        """
        logger.info("--- TOOL USED: run_iot_analysis_and_wait (%s) ---", analysis_id)
        token = await get_token(ctx)
        return await run_iot_analysis_and_wait(analysis_id, token)

    @mcp.tool()
    async def copy_iot_analyses_tool(analysis_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT analyses.

        Args:
            analysis_ids (list[str]): List of analysis identifiers to copy.
        """
        logger.info("--- TOOL USED: copy_iot_analyses (%s items) ---", len(analysis_ids))
        token = await get_token(ctx)
        return await copy_iot_analyses(analysis_ids, token)

    @mcp.tool()
    async def get_iot_analysis_results(analysis_id: str, job_id: str, ctx: Context) -> dict:
        """
        Retrieves the status and results of a specific IoT analysis job.

        Args:
            analysis_id (str): The identifier of the analysis.
            job_id (str): The identifier of the specific job run.
        """
        logger.info("--- TOOL USED: get_iot_analysis_results (%s, %s) ---", analysis_id, job_id)
        token = await get_token(ctx)
        return await get_iot_analysis_job(analysis_id, job_id, token)

    @mcp.tool()
    async def get_iot_analysis_output_tables_tool(analysis_id: str, ctx: Context) -> list[str]:
        """
        Finds the names of CAS tables generated by an IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info("--- TOOL USED: get_iot_analysis_output_tables (%s) ---", analysis_id)
        token = await get_token(ctx)
        analysis = await get_iot_analysis(analysis_id, token)
        
        tables = []
        for step in analysis.get("steps", []):
            for param in step.get("outputParameters", []):
                if param.get("parameterName") in ["OUTPUT_TABLE", "OUT_TABLE", "SC_TABLE"]:
                    val = param.get("parameterValue")
                    if val and val not in tables:
                        tables.append(val)
        return tables

    @mcp.tool()
    async def list_iot_models_tool(ctx: Context) -> dict:
        """
        Lists all registered models in SAS Analytics for IoT.
        """
        logger.info("--- TOOL USED: list_iot_models ---")
        token = await get_token(ctx)
        return await list_iot_models(token)

    @mcp.tool()
    async def get_iot_model_definition_tool(model_name: str, ctx: Context) -> dict:
        """
        Retrieves metadata and parameter definitions for a specific AIoT model.

        Args:
            model_name (str): The name/ID of the model (e.g., 'EXPLORATION_ASSET').
        """
        logger.info("--- TOOL USED: get_iot_model_definition (%s) ---", model_name)
        token = await get_token(ctx)
        return await get_iot_model(model_name, token)

    @mcp.tool()
    async def list_emerging_issue_runs_tool(
        ctx: Context,
        start: int = 0,
        limit: int = 10,
        name: str = None,  # pyright: ignore
        status: str = None,  # pyright: ignore
        created_by: str = None,  # pyright: ignore
        owner: str = None,  # pyright: ignore
        attribute_filters: dict = None,  # pyright: ignore
        sort_by: str = "lastRunDate",
        sort_order: str = "desc",
    ) -> dict:
        """
        Lists all Emerging Issue analysis runs (returns top 10 by default, sorted descending by lastRunDate).
        Supports filtering and sorting by any attribute (e.g., lastRunDate, name, status, owner, createdBy).

        Args:
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            name (str): Optional case-insensitive substring filter for run name (e.g., 'Emerging')
            status (str): Optional case-insensitive substring filter for run status (e.g., 'Completed')
            created_by (str): Optional case-insensitive substring filter for creator name (e.g., 'germsz')
            owner (str): Optional case-insensitive substring filter for owner username or display name
            attribute_filters (dict): Optional dictionary mapping any attribute name to target value
                                      for dynamic filtering
            sort_by (str): Attribute to sort runs by before pagination (default: 'lastRunDate')
            sort_order (str): Sort direction: 'desc' (default) or 'asc'
        """
        logger.info("--- TOOL USED: list_emerging_issue_runs ---")
        token = await get_token(ctx)

        # Fetch all items in batches
        all_items = []
        current_start = 0
        fetch_limit = 100

        while True:
            raw_data = await list_iot_analyses(
                token,
                start=current_start,
                limit=fetch_limit
            )
            items = raw_data.get("items", [])
            all_items.extend(items)
            
            if len(items) < fetch_limit:
                break
            current_start += fetch_limit

        # Filter by Emerging Issues model types
        filtered_items = [
            item for item in all_items
            if "EI" in item.get("modelName", "").upper()
            or "EMERGING" in item.get("modelName", "").upper()
            or "EMERGING" in item.get("name", "").upper()
        ]

        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        if name:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("name"), name)]
        if status:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("status"), status)]
        if created_by:
            filtered_items = [item for item in filtered_items if matches_filter(item.get("createdBy"), created_by)]
        if owner:
            filtered_items = [
                item for item in filtered_items
                if matches_filter(item.get("currentOwner"), owner)
                or matches_filter(item.get("currentOwnerDisplayName"), owner)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_items = [item for item in filtered_items if matches_filter(item.get(attr), val)]

        pruned_all = [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "modelName": item.get("modelName"),
                "status": item.get("status"),
                "displayStatus": item.get("displayStatus"),
                "lastRunDate": item.get("lastRunDate"),
                "createdBy": item.get("createdBy"),
                "currentOwner": item.get("currentOwner"),
                "currentOwnerDisplayName": item.get("currentOwnerDisplayName"),
                "dataSelectionId": item.get("dataSelectionId"),
                "description": item.get("description"),
            }
            for item in filtered_items
        ]

        return _paginate_sorted_items(
            pruned_all,
            start=start,
            limit=limit,
            sort_by=sort_by,
            sort_order=sort_order,
            item_label="Emerging Issue runs",
        )

    @mcp.tool()
    async def list_alerts_for_run_tool(
        analysis_id: str,
        ctx: Context,
        start: int = 0,
        limit: int = 10,
        alert_id: str | None = None,
        alert_type: str | None = None,
        model_cd: str | None = None,
        cstmr_country_cd: str | None = None,
        seasonal_flag: str | None = None,
        display_status_cd: str | None = None,
        attribute_filters: dict | None = None,
        sort_by: str = "score",
        sort_order: str = "desc",
    ) -> dict:
        """
        Retrieves the list of alerts generated by a completed Emerging Issue analysis run.
        Sorts all matching alerts by `sort_by` (default: 'score' descending) BEFORE slicing
        to the top `limit` (default: 10), and includes `has_more`, `remaining_count`,
        `next_start`, and `pagination_hint` to show the rest of the list.

        Args:
            analysis_id (str): The unique ID of the Emerging Issue analysis/run.
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            alert_id (str): Optional case-insensitive filter for alert ID
            alert_type (str): Optional case-insensitive filter for alert type (e.g., 'PRODUCTIONPERIOD')
            model_cd (str): Optional case-insensitive filter for model code (e.g., 'Beta', 'Abyss')
            cstmr_country_cd (str): Optional case-insensitive filter for customer country code (e.g., '840')
            seasonal_flag (str): Optional case-insensitive filter for seasonal flag (e.g., 'N', 'Y')
            display_status_cd (str): Optional case-insensitive filter for display status code (e.g., 'Active')
            attribute_filters (dict): Optional dictionary of additional attribute-value filters
            sort_by (str): Alert attribute to sort by before pagination (default: 'score'; also supports 'cost_score',
                           'Events', 'Acceleration_AP', 'Acceleration', 'alert_id', etc.)
            sort_order (str): Sort direction: 'desc' (default) or 'asc'
        """
        logger.info("--- TOOL USED: list_alerts_for_run (%s) ---", analysis_id)
        token = await get_token(ctx)

        # 1. Retrieve the analysis definition to check its shortId
        analysis = await get_iot_analysis(analysis_id, token)
        short_id = analysis.get("shortId")
        if not short_id:
            short_id = analysis_id.split("-")[0]

        model_name = analysis.get("modelName", "EIENTERPRISE_PRODUCT")
        prefix = model_name.split("_")[0] if "_" in model_name else model_name
        default_table = _validate_sas_identifier(f"{prefix}_ALERTS_{short_id}".upper(), "table")

        # 2. Discover and export the alerts table in a single compute snippet
        #    (binds only QASANLOUT rather than caslib _all_ assign, and terminates the CAS session).
        export_code = f"""
        cas mySession;
        libname mycas cas caslib="QASANLOUT" sessref=mySession;

        proc cas;
          table.tableInfo r=t / caslib="QASANLOUT";
          matched = "";
          do row over t.TableInfo;
            if index(upcase(row.Name), upcase("_ALERTS_{short_id}")) > 0 then matched = upcase(row.Name);
          end;
          if matched = "" then matched = "{default_table}";
          symputx("ALERT_TBL", matched, "G");
        quit;

        %macro _export_alerts;
          %if %sysfunc(exist(mycas.&ALERT_TBL)) %then %do;
            filename myjson temp;
            proc json out=myjson pretty;
              export mycas.&ALERT_TBL;
            run;

            data _null_;
              infile myjson;
              input;
              put "JSON_OUT: " _infile_;
            run;
          %end;
        %mend _export_alerts;
        %_export_alerts;
        cas mySession terminate;
        """

        export_res = await run_one_snippet(export_code, "export_alerts", token)
        export_log = export_res.get("log", "")
        matched_table = default_table

        # 3. Extract and parse JSON data
        json_lines = []
        for line in export_log.splitlines():
            if line.startswith("JSON_OUT: "):
                json_lines.append(line[len("JSON_OUT: "):])

        json_str = "\n".join(json_lines)
        if not json_str.strip():
            logger.error("No JSON output from PROC JSON. Check log: %s", export_log)
            return {
                "items": [],
                "total": 0,
                "count": 0,
                "returned_count": 0,
                "start": start,
                "limit": limit,
                "sort_by": sort_by,
                "sort_order": (sort_order or "desc").lower(),
                "has_more": False,
                "remaining_count": 0,
                "next_start": None,
                "message": (
                    f"No alerts found for run '{analysis_id}'. It might not "
                    f"have generated any alerts or table '{matched_table}' is empty."
                ),
            }

        try:
            parsed_data = json.loads(json_str)
            alerts = []
            for key, val in parsed_data.items():
                if key.startswith("SASTableData"):
                    alerts = val
                    break
        except Exception as e:
            logger.exception("Failed to parse PROC JSON output from SAS log")
            return {
                "items": [],
                "total": 0,
                "count": 0,
                "returned_count": 0,
                "start": start,
                "limit": limit,
                "sort_by": sort_by,
                "sort_order": (sort_order or "desc").lower(),
                "has_more": False,
                "remaining_count": 0,
                "next_start": None,
                "error": f"Failed to parse alerts data from SAS log: {str(e)}",
            }

        # 5. Apply filtering on retrieved alerts
        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        filtered_alerts = [_annotate_fqa_alert(a) for a in alerts]

        if alert_id:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "alert_id"), alert_id)
            ]
        if alert_type:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "alert_type"), alert_type)
            ]
        if model_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "model_cd"), model_cd)
            ]
        if cstmr_country_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "cstmr_country_cd"), cstmr_country_cd)
            ]
        if seasonal_flag:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "seasonal_flag"), seasonal_flag)
            ]
        if display_status_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(_extract_field_case_insensitive(a, "display_status_cd"), display_status_cd)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_alerts = [
                    a for a in filtered_alerts
                    if matches_filter(_extract_field_case_insensitive(a, attr), val)
                ]

        return _paginate_sorted_items(
            filtered_alerts,
            start=start,
            limit=limit,
            sort_by=sort_by,
            sort_order=sort_order,
            item_label=f"alerts for run {analysis_id}",
        )

    @mcp.tool()
    async def list_folders_and_projects_tool(folder_id: str = None, ctx: Context = None) -> dict:  # pyright: ignore
        """
        Lists folders, projects, and other members within a parent folder.
        If no folder_id is specified, lists root level folders and the user's home folder.

        Args:
            folder_id (str): Optional parent folder ID or URI.
        """
        logger.info("--- TOOL USED: list_folders_and_projects (folder_id=%s) ---", folder_id)
        token = await get_token(ctx)
        return await list_folders_and_projects(token, folder_id)

    @mcp.tool()
    async def create_folder_tool(
        name: str,
        parent_folder_id: str = "@myFolder",
        description: str = None,  # pyright: ignore
        ctx: Context = None  # pyright: ignore
    ) -> dict:
        """
        Creates a new folder inside a parent folder.

        Args:
            name (str): Name of the new folder.
            parent_folder_id (str): Parent folder ID or shortcut (defaults to '@myFolder').
            description (str): Optional folder description.
        """
        logger.info("--- TOOL USED: create_folder (name=%s, parent=%s) ---", name, parent_folder_id)
        token = await get_token(ctx)
        return await create_folder(name, token, parent_folder_id, description)

    @mcp.tool()
    async def create_project_tool(
        name: str,
        folder_id: str = "@myFolder",
        description: str = None,  # pyright: ignore
        ctx: Context = None  # pyright: ignore
    ) -> dict:
        """
        Creates a new IoT project under a folder.

        Args:
            name (str): Name of the project.
            folder_id (str): Folder ID to place the project in (defaults to '@myFolder').
            description (str): Optional project description.
        """
        logger.info("--- TOOL USED: create_project (name=%s, folder=%s) ---", name, folder_id)
        token = await get_token(ctx)
        return await create_project(name, token, folder_id, description)

    @mcp.tool()
    async def delete_folder_tool(folder_id: str, ctx: Context = None) -> str:  # pyright: ignore
        """
        Deletes an existing folder by its ID or URI.

        Args:
            folder_id (str): The ID of the folder to delete.
        """
        logger.info("--- TOOL USED: delete_folder (folder_id=%s) ---", folder_id)
        token = await get_token(ctx)
        await delete_folder(folder_id, token)
        return f"Folder {folder_id} deleted successfully."

    @mcp.tool()
    async def delete_project_tool(project_id: str, ctx: Context = None) -> str:  # pyright: ignore
        """
        Deletes an existing IoT project by its ID.

        Args:
            project_id (str): The ID of the project to delete.
        """
        logger.info("--- TOOL USED: delete_project (project_id=%s) ---", project_id)
        token = await get_token(ctx)
        await delete_project(project_id, token)
        return f"Project {project_id} deleted successfully."

    @mcp.tool()
    async def run_pareto_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "CLAIM.EVENT_STATUS_CD",
        report_var: str = "PRODUCT.MODEL_CD",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        num_bars: int = 20,
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = False,
        usage_profile: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        value_var: str = "ACTUAL_VALUE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Pareto Analysis instance on product/claim data.
        Exposes all standard variables and parameters for Pareto analysis.

        Args:
            name (str): Unique name for the Pareto analysis.
            data_selection_id (str): ID of the launched data selection to analyze.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable (default: 'CLAIM.EVENT_STATUS_CD').
            report_var (str): Report by variable (default: 'PRODUCT.MODEL_CD').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            num_bars (int): Number of bars to display (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: False).
            usage_profile (bool): Usage profile flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            value_var (str): Value variable (default: 'ACTUAL_VALUE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_pareto_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "NUMBARS": num_bars,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "VALUEVAR": value_var,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="PARETO_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_trend_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        report_var: str = "PRODUCT.PRODUCTION_MONTH",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        calc_method: str = "ASIS",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = True,
        usage_profile: bool = False,
        control_charts: bool = True,
        control_limits_type: str = "SYSTEM",
        display_grid: bool = False,
        ucl: str = "",
        lcl: str = "",
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Trend & Control Analysis instance on product/claim data.
        Exposes all variables and parameters for Trend & Control analysis.

        Args:
            name (str): Unique name for the Trend analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            report_var (str): Report by variable (default: 'PRODUCT.PRODUCTION_MONTH').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            control_charts (bool): Display control charts (default: True).
            control_limits_type (str): Control limits type (default: 'SYSTEM').
            display_grid (bool): Display chart grid (default: False).
            ucl (str): Upper control limit.
            lcl (str): Lower control limit.
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_trend_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "CALCMETHOD": calc_method,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "CONTROLCHARTS": "TRUE" if control_charts else "FALSE",
            "CONTROLLIMITSTYPE": control_limits_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "UCL": ucl,
            "LCL": lcl,
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TREND_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_trend_by_exposure_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        report_var: str = "PRODUCT.PRODUCTION_MONTH",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        max_by_var: int = 20,
        calc_method: str = "ASIS",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = True,
        usage_profile: bool = False,
        control_charts: bool = True,
        control_limits_type: str = "SYSTEM",
        display_grid: bool = False,
        ucl: str = "",
        lcl: str = "",
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Trend by Exposure Analysis instance on product/claim data.

        Args:
            name (str): Unique name for the Trend by Exposure analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            report_var (str): Report by variable (default: 'PRODUCT.PRODUCTION_MONTH').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            max_by_var (int): Max by variable count (default: 20).
            calc_method (str): Calculation method (default: 'ASIS').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            control_charts (bool): Display control charts (default: True).
            control_limits_type (str): Control limits type (default: 'SYSTEM').
            display_grid (bool): Display chart grid (default: False).
            ucl (str): Upper control limit.
            lcl (str): Lower control limit.
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_trend_by_exposure_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "MAXBYVAR": max_by_var,
            "CALCMETHOD": calc_method,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "CONTROLCHARTS": "TRUE" if control_charts else "FALSE",
            "CONTROLLIMITSTYPE": control_limits_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "UCL": ucl,
            "LCL": lcl,
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TRENDEXP_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_detail_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.PRODUCTION_DATE,PRODUCT.INSERVICE_DATE,"
            "PRODUCT.SELLING_DEALER_CD,CLAIM.USAGE,"
            "CLAIM.PRIM_LABOR_CD,CLAIM.PRIM_REPL_PART_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        comment_vars: str = "",
        min_num_comments: int = 25,
        num_similar_comments: str = "5 10 25 50",
        max_num_svd_dimensions: int = 50,
        find_similar_comments: bool = False,
        include_nc_products: bool = False,
        language: str = "english",
        run_on_transposed: str = "N",
        usage_type: str = "",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        display_type: str = "CODE",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Detail Analysis instance on product/claim data.
        Exposes all variables and parameters for Detail analysis.

        Args:
            name (str): Unique name for the Detail analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            comment_vars (str): Comment variables.
            min_num_comments (int): Min comments (default: 25).
            num_similar_comments (str): Num similar comments (default: '5 10 25 50').
            max_num_svd_dimensions (int): Max SVD dimensions (default: 50).
            find_similar_comments (bool): Find similar comments (default: False).
            include_nc_products (bool): Include non-conforming products (default: False).
            language (str): Comment analysis language (default: 'english').
            run_on_transposed (str): Run on transposed flag (default: 'N').
            usage_type (str): Usage measurement type.
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            display_type (str): Display type (default: 'CODE').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_detail_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "COMMENTVARS": comment_vars,
            "MINNUMCOMMENTS": min_num_comments,
            "NUMSIMILARCOMMENTS": num_similar_comments,
            "MAXNUMSVDDIMENSIONS": max_num_svd_dimensions,
            "FINDSIMILARCOMMENTS": "TRUE" if find_similar_comments else "FALSE",
            "INCLUDENCPRODUCTS": "TRUE" if include_nc_products else "FALSE",
            "LANGUAGE": language,
            "RUNONTRANSPOSED": run_on_transposed,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "DISPLAYTYPE": display_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="DETAIL_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )
    @mcp.tool()
    async def run_statistical_driver_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_COUNTRY_CD,"
            "CLAIM.EVENT_TYPE_CD,CLAIM.EVENT_STATUS_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        alpha_level: float = 0.05,
        max_report_level: int = 500,
        area_of_opportunity_unit: int = 1,
        display_grid: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Statistical Drivers Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            alpha_level (float): Alpha significance level (default: 0.05).
            max_report_level (int): Max report level (default: 500).
            area_of_opportunity_unit (int): Area of opportunity unit (default: 1).
            display_grid (bool): Display grid lines (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_statistical_driver_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "ALPHALEVEL": alpha_level,
            "MAXREPORTLEVEL": max_report_level,
            "AREAOFOPPORTUNITYUNIT": area_of_opportunity_unit,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="STATDRIVER_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_decision_tree_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "",
        report_var: str = (
            "PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_COUNTRY_CD,"
            "CLAIM.EVENT_TYPE_CD,CLAIM.EVENT_STATUS_CD"
        ),
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        max_branch: int = 2,
        max_depth: int = 5,
        leaf_size: float = 0.01,
        alpha_level: float = 0.05,
        min_num_obs: int = 10,
        max_report_level: int = 100,
        max_report_var: int = 25,
        area_of_opportunity_unit: int = 1,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        unique_value: bool = False,
        usage_profile: bool = False,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Decision Tree Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable.
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            max_branch (int): Maximum branches (default: 2).
            max_depth (int): Maximum depth (default: 5).
            leaf_size (float): Leaf size proportion (default: 0.01).
            alpha_level (float): Alpha significance level (default: 0.05).
            min_num_obs (int): Minimum observations in leaf (default: 10).
            max_report_level (int): Maximum report level (default: 100).
            max_report_var (int): Maximum report variables (default: 25).
            area_of_opportunity_unit (int): Area of opportunity unit (default: 1).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            unique_value (bool): Force unique value (default: False).
            usage_profile (bool): Usage profile flag (default: False).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_decision_tree_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "MAXBRANCH": max_branch,
            "MAXDEPTH": max_depth,
            "LEAFSIZE": leaf_size,
            "ALPHALEVEL": alpha_level,
            "MINNUMOBS": min_num_obs,
            "MAXREPORTLEVEL": max_report_level,
            "MAXREPORTVAR": max_report_var,
            "AREAOFOPPORTUNITYUNIT": area_of_opportunity_unit,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="MULTIVARIATE_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_event_forecasting_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOUNT",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        forecast_periods: int = 0,
        forecast_interval: str = "MONTH",
        forecast_model_type: str = "RepeatEvent",
        forecast_model: str = "MCF",
        confidence: float = 0.95,
        wrty_time_length: int = 36,
        fore_wrty_length: str = "",
        fore_wrty_usage_mileage: str = "",
        fore_wrty_usage_hours: str = "",
        fore_wrty_usage_km: str = "",
        pct_pts: str = "95",
        sales_forecast_source: str = "",
        sales_forecast_calc: str = "",
        sales_forecast_alloc: str = "P",
        sales_forecast_n: int = 0,
        sales_forecast: str = "",
        seas_interval: str = "days10",
        seas_sle: float = 0.05,
        seas_sls: float = 0.05,
        seaseps: float = 1.0e-3,
        seasfreqs: int = 24,
        seasjmax: int = 15,
        seasmintime: int = 0,
        target_num_intervals: int = 1500,
        seasonal_nhpp: bool = False,
        include_model_eqn: bool = True,
        apply_war_date: str = "Y",
        apply_war_usage: str = "Y",
        censor_date_source: str = "D",
        censor_date: str = "",
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        exposure_type: str = "TIS",
        max_by_var: int = 20,
        max_interval_size: int = 10,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs an Event Forecasting Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOUNT').
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            forecast_periods (int): Forecast periods count (default: 0).
            forecast_interval (str): Forecast interval (default: 'MONTH').
            forecast_model_type (str): Forecast model type (default: 'RepeatEvent').
            forecast_model (str): Forecast model (default: 'MCF').
            confidence (float): Confidence level (default: 0.95).
            wrty_time_length (int): Warranty time length (default: 36).
            fore_wrty_length (str): Forecast warranty length.
            fore_wrty_usage_mileage (str): Forecast warranty max mileage.
            fore_wrty_usage_hours (str): Forecast warranty max hours.
            fore_wrty_usage_km (str): Forecast warranty max km.
            pct_pts (str): Percentile points (default: '95').
            sales_forecast_source (str): Sales forecast source.
            sales_forecast_calc (str): Sales forecast calculation method.
            sales_forecast_alloc (str): Sales forecast allocation (default: 'P').
            sales_forecast_n (int): Sales forecast N value.
            sales_forecast (str): Sales forecast.
            seas_interval (str): Seasonal interval (default: 'days10').
            seas_sle (float): Seasonal entry significance (default: 0.05).
            seas_sls (float): Seasonal stay significance (default: 0.05).
            seaseps (float): Seasonal convergence epsilon (default: 1.0e-3).
            seasfreqs (int): Seasonal frequency (default: 24).
            seasjmax (int): Seasonal JMax value (default: 15).
            seasmintime (int): Seasonal minimum time.
            target_num_intervals (int): Target intervals (default: 1500).
            seasonal_nhpp (bool): Seasonal NHPP model flag (default: False).
            include_model_eqn (bool): Include model equation flag (default: True).
            apply_war_date (str): Apply warranty date flag (default: 'Y').
            apply_war_usage (str): Apply warranty usage flag (default: 'Y').
            censor_date_source (str): Censor date source (default: 'D').
            censor_date (str): Censor date value.
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            exposure_type (str): Exposure type (default: 'TIS').
            max_by_var (int): Max by variable count (default: 20).
            max_interval_size (int): Max interval size (default: 10).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_event_forecasting_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "FORECASTPERIODS": forecast_periods,
            "FORECAST_INTERVAL": forecast_interval,
            "FORECASTMODELTYPE": forecast_model_type,
            "FORECASTMODEL": forecast_model,
            "CONFIDENCE": confidence,
            "WRTYTIMELENGTH": wrty_time_length,
            "FOREWRTYLENGTH": fore_wrty_length,
            "FOREWRTYUSAGEMILEAGE": fore_wrty_usage_mileage,
            "FOREWRTYUSAGEHOURS": fore_wrty_usage_hours,
            "FOREWRTYUSAGEKM": fore_wrty_usage_km,
            "PCTLPTS": pct_pts,
            "SALESFORECASTSOURCE": sales_forecast_source,
            "SALESFORECASTCALC": sales_forecast_calc,
            "SALESFORECASTALLOC": sales_forecast_alloc,
            "SALESFORECASTN": sales_forecast_n,
            "SALESFORECAST": sales_forecast,
            "SEAS_INTERVAL": seas_interval,
            "SEAS_SLE": seas_sle,
            "SEAS_SLS": seas_sls,
            "SEASEPS": seaseps,
            "SEASFREQS": seasfreqs,
            "SEASJMAX": seasjmax,
            "SEASMINTIME": seasmintime,
            "TARGETNUMINTERVALS": target_num_intervals,
            "SEASONALNHPP": "TRUE" if seasonal_nhpp else "FALSE",
            "INCLUDEMODELEQN": "TRUE" if include_model_eqn else "FALSE",
            "APPLYWARDATE": apply_war_date,
            "APPLYWARUSAGE": apply_war_usage,
            "CENSORDATESOURCE": censor_date_source,
            "CENSORDATE": censor_date,
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "EXPOSURETYPE": exposure_type,
            "MAXBYVAR": max_by_var,
            "MAXINTERVALSIZE": max_interval_size,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="FORECASTING_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_summary_tables_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOUNT",
        report_var: str = "PRODUCT.MODEL_CD,PRODUCT.PRODUCTION_YEAR",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        subtotals: bool = True,
        use_exposure_type: bool = False,
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        unique_value: bool = True,
        usage_profile: bool = False,
        usage_bins_to_display: str = "500,1000,1500,2000",
        tis_bins_to_display: str = "0,1,2,3,4,5,6",
        bin_increment: int = 0,
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Summary Tables (Crosstab) Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOUNT').
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            subtotals (bool): Display subtotals (default: True).
            use_exposure_type (bool): Use exposure type (default: False).
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            usage_bins_to_display (str): Bins to display for usage.
            tis_bins_to_display (str): Bins to display for TIS.
            bin_increment (int): Bin increment size (default: 0).
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_summary_tables_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "SUBTOTALS": "TRUE" if subtotals else "FALSE",
            "USEEXPOSURETYPE": "TRUE" if use_exposure_type else "FALSE",
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGEBINSTODISPLAY": usage_bins_to_display,
            "TISBINSTODISPLAY": tis_bins_to_display,
            "BININCREMENT": bin_increment,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="CROSSTAB_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_text_mining_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.TOTAL_EVENT_AMT",
        report_var: str = "PRODUCT.MODEL_CD,CLAIM.EVENT_STATUS_CD",
        text_var: str = "CLAIM.CSTMR_COMMENT",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        language: str = "Auto",
        custom_category: bool = True,
        num_topics: int = 10,
        num_terms: int = 10,
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Text Mining Analysis on product/claim comment data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.TOTAL_EVENT_AMT').
            report_var (str): Report by variables.
            text_var (str): Target text column containing comments (default: 'CLAIM.CSTMR_COMMENT').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            language (str): Comment language (default: 'Auto').
            custom_category (bool): Custom category analysis flag (default: True).
            num_topics (int): Number of topics to discover (default: 10).
            num_terms (int): Number of terms per topic to return (default: 10).
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_text_mining_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "TEXTVAR": text_var,
            "DATADOMAIN": data_domain,
            "LANGUAGE": language,
            "CUSTOM_CATEGORY": "TRUE" if custom_category else "FALSE",
            "NUMTOPICS": num_topics,
            "NUMTERMS": num_terms,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TEXTANALYSIS_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_exposure_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "Y",
        unique_value: bool = True,
        usage_profile: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        display_grid: bool = False,
        bin_increment: int = 0,
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs an Exposure Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'Y').
            unique_value (bool): Force unique value (default: True).
            usage_profile (bool): Usage profile flag (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            display_grid (bool): Display grid lines (default: False).
            bin_increment (int): Bin increment size (default: 0).
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_exposure_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "BININCREMENT": bin_increment,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="EXPOSURE_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_failure_relationships_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "PART.REPL_PART_AMT",
        report_var: str = "PART.REPL_PART_CD",
        data_domain: str = "PRODUCT,CLAIM,PART",
        rv_dim_column: str = "PART.REPL_PART_CD",
        threshold_slider_variable: str = "CONF",
        xvar1: str = "iotIncr",
        dmdb_max_lev: int = 100001,
        chart_scaling_factor: int = 400,
        node_tip: str = "CODE",
        node_size: str = "UNIFORM",
        bin_increment: int = 500,
        rv_table_name_key: str = "PART.REPL_PART_CD",
        rv_table_name_value: str = "PART.REPL_PART_CD",
        rv_table_name: str = "PART.REPL_PART_CD",
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        link_tip: str = "DESC",
        link_value_variable: str = "conf",
        link_width: str = "UNIFORM",
        link_width_variable: str = "count",
        max_link_number: int = 2000,
        max_link_width: int = 3,
        max_node_number: int = 300,
        min_items: int = 2,
        nodesize_variable: str = "count",
        min_conf_passoc: float = 1.0,
        bin_length: int = 30,
        onetrvruledsflag: int = 0,
        pseudoliftincludeflag: str = "N",
        sas_file: int = 1,
        seq_proc_threshold: int = 301,
        show_immature_exposure: str = "N",
        threshold_slider_scale_type: str = "PERCENTILE",
        assoc_table_threshold: int = 100,
        trule_end_start_flag: str = "ALL",
        uniform_link_width: int = 1,
        rule_type: str = "TYPE4",
        perform_repeat_repair: bool = False,
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        max_inter_oc_time: int = 3,
        min_conf_p: str = "",
        min_lift: str = "",
        min_cost: int = 15000,
        no_rules_to_display: str = "",
        yvar2: str = "CONF",
        yvar1: str = "SUPPORT",
        xvar2: str = "iotIncr",
        rule_filter_criteria: str = "support",
        tis_point_of_view: str = "frombuild",
        apply_int_oc_time_incr: bool = False,
        apply_rule_st_criteria: bool = True,
        min_support_type: str = "percent",
        rule_size: str = "1-1,1-2,2-1,2-2",
        min_support_p: float = 0.01,
        min_support_c: int = 1,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Failure Relationships Analysis on product/claim/part data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'PART.REPL_PART_AMT').
            report_var (str): Report by variables.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,PART').
            rv_dim_column (str): RV dimension column.
            threshold_slider_variable (str): Threshold slider variable.
            xvar1 (str): X variable 1 (default: 'iotIncr').
            dmdb_max_lev (int): DMDB maximum level (default: 100001).
            chart_scaling_factor (int): Chart scaling factor (default: 400).
            node_tip (str): Node tooltip display type (default: 'CODE').
            node_size (str): Node sizing logic (default: 'UNIFORM').
            bin_increment (int): Bin increment size (default: 500).
            rv_table_name_key (str): RV table name key.
            rv_table_name_value (str): RV table name value.
            rv_table_name (str): RV table name.
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            link_tip (str): Link tooltip type (default: 'DESC').
            link_value_variable (str): Link value variable.
            link_width (str): Link width (default: 'UNIFORM').
            link_width_variable (str): Link width variable (default: 'count').
            max_link_number (int): Maximum links (default: 2000).
            max_link_width (int): Maximum link width (default: 3).
            max_node_number (int): Maximum nodes (default: 300).
            min_items (int): Minimum items in association rules (default: 2).
            nodesize_variable (str): Node sizing variable (default: 'count').
            min_conf_passoc (float): Minimum confidence passoc (default: 1.0).
            bin_length (int): Bin length (default: 30).
            onetrvruledsflag (int): One transaction rule dataset flag (default: 0).
            pseudoliftincludeflag (str): Include pseudo lift flag (default: 'N').
            sas_file (int): SAS file number (default: 1).
            seq_proc_threshold (int): Sequence process threshold (default: 301).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            threshold_slider_scale_type (str): Scale type (default: 'PERCENTILE').
            assoc_table_threshold (int): Association table threshold (default: 100).
            trule_end_start_flag (str): Rule start/end flag (default: 'ALL').
            uniform_link_width (int): Uniform link width (default: 1).
            rule_type (str): Association rule type (default: 'TYPE4').
            perform_repeat_repair (bool): Perform repeat repair analysis (default: False).
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            max_inter_oc_time (int): Maximum inter-event occurrence time.
            min_conf_p (str): Minimum confidence percentage.
            min_lift (str): Minimum lift.
            min_cost (int): Minimum cost limit (default: 15000).
            no_rules_to_display (str): Number of rules to display.
            yvar2 (str): Y variable 2 (default: 'CONF').
            yvar1 (str): Y variable 1 (default: 'SUPPORT').
            xvar2 (str): X variable 2 (default: 'iotIncr').
            rule_filter_criteria (str): Rule filtering criteria (default: 'support').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            apply_int_oc_time_incr (bool): Apply interval time increment.
            apply_rule_st_criteria (bool): Apply rule constraint criteria (default: True).
            min_support_type (str): Minimum support type (default: 'percent').
            rule_size (str): Rule size filter (default: '1-1,1-2,2-1,2-2').
            min_support_p (float): Minimum support percentage (default: 0.01).
            min_support_c (int): Minimum support count (default: 1).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_failure_relationships_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "DATADOMAIN": data_domain,
            "RVDIMCOLUMN": rv_dim_column,
            "THRESHOLDSLIDERVARIABLE": threshold_slider_variable,
            "XVAR1": xvar1,
            "DMDBMAXLEV": dmdb_max_lev,
            "CHARTSCALINGFACTOR": chart_scaling_factor,
            "NODETIP": node_tip,
            "NODESIZE": node_size,
            "BININCREMENT": bin_increment,
            "RVTABLEVALUE": rv_table_name_value,
            "RVTABLENAMEKEY": rv_table_name_key,
            "RVTABLENAMEVALUE": rv_table_name_value,
            "RVTABLENAME": rv_table_name,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "LINKTIP": link_tip,
            "LINKVALUEVARIABLE": link_value_variable,
            "LINKWIDTH": link_width,
            "LINKWIDTHVARIABLE": link_width_variable,
            "MAXLINKNUMBER": max_link_number,
            "MAXLINKWIDTH": max_link_width,
            "MAXNODENUMBER": max_node_number,
            "MINITEMS": min_items,
            "NODESIZEVARIABLE": nodesize_variable,
            "MINCONFPASSOC": min_conf_passoc,
            "BINLENGTH": bin_length,
            "ONETRVRULEDSFLAG": onetrvruledsflag,
            "PSEUDOLIFTINCLUDEFLAG": pseudoliftincludeflag,
            "SASFILE": sas_file,
            "SEQPROCTHRESHOLD": seq_proc_threshold,
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "THRESHOLDSLIDERSCALETYPE": threshold_slider_scale_type,
            "ASSOCTABLETHRESHOLD": assoc_table_threshold,
            "TRULEENDSTARTFLAG": trule_end_start_flag,
            "UNIFORMLINKWIDTH": uniform_link_width,
            "RULETYPE": rule_type,
            "PERFORMREPEATREPAIR": "TRUE" if perform_repeat_repair else "FALSE",
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MAXINTEROCTIME": max_inter_oc_time,
            "MINCONFP": min_conf_p,
            "MINLIFT": min_lift,
            "MINCOST": min_cost,
            "NORULESTODISPLAY": no_rules_to_display,
            "YVAR2": yvar2,
            "YVAR1": yvar1,
            "XVAR2": xvar2,
            "RULEFILTERCRITERIA": rule_filter_criteria,
            "TISPOINTOFVIEW": tis_point_of_view,
            "APPLYINTOCTIMEINCR": "TRUE" if apply_int_oc_time_incr else "FALSE",
            "APPLYRULESTCRITERIA": "TRUE" if apply_rule_st_criteria else "FALSE",
            "MINSUPPORTTYPE": min_support_type,
            "RULESIZE": rule_size,
            "MINSUPPORTP": min_support_p,
            "MINSUPPORTC": min_support_c,
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="FAILREL_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_geographic_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        report_var: str = "PRODUCT.SELLING_DEALER_COUNTRY_CD",
        color_var: str = "CLAIM.CLAIMCOUNT",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        tis_point_of_view: str = "frombuild",
        calc_method: str = "ASIS",
        exp_chart_type: str = "cumulative",
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = "N",
        unique_value: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        failures: str = "all",
        maturity_level: str = "",
        max_exp_val: str = "",
        min_sample_size: int = 0,
        min_sample_size_type: str = "",
        claim_submit_lag: bool = True,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Geographic Analysis on product/claim geographic data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            report_var (str): Report by variables.
            color_var (str): Variable to determine map region colors.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            calc_method (str): Calculation method (default: 'ASIS').
            exp_chart_type (str): Exposure chart type (default: 'cumulative').
            exp_measurement_type (int): Exposure measurement type (default: 1).
            find_exp_measurement (bool): Find exposure measurement (default: True).
            find_first_fail_flag (bool): Find first fail flag (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            unique_value (bool): Force unique value (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            failures (str): Failure type filter (default: 'all').
            maturity_level (str): Maturity level.
            max_exp_val (str): Max exposure value.
            min_sample_size (int): Min sample size (default: 0).
            min_sample_size_type (str): Min sample size type.
            claim_submit_lag (bool): Claim submit lag flag (default: True).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_geographic_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "COLORVAR": color_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "TISPOINTOFVIEW": tis_point_of_view,
            "CALCMETHOD": calc_method,
            "EXPCHARTTYPE": exp_chart_type,
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "FAILURES": failures,
            "MATURITYLEVEL": maturity_level,
            "MAXEXPVAL": max_exp_val,
            "MINSAMPLESIZE": min_sample_size,
            "MINSAMPLESIZETYPE": min_sample_size_type,
            "CLAIMSUBMITLAG": "TRUE" if claim_submit_lag else "FALSE",
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="GEOGRAPHIC_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_time_of_event_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "CLAIM.CLAIMCOST",
        report_var: str = "CLAIM.EVENT_PAID_MONTH",
        by_var: str = "",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exposure_type: str = "TIS",
        find_first_fail_flag: bool = False,
        exp_measurement_type: int = 1,
        unique_value: bool = False,
        show_immature_exposure: str = "N",
        tis_point_of_view: str = "frombuild",
        wrty_time_length: int = 12,
        usage_profile: bool = False,
        usage_type: str = "mileage",
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = "",
        repair_before_sold: bool = True,
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False,
        display_grid: bool = False,
        display_type: str = "CODE",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Time of Event (Time of Claim) Analysis on product/claim data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'CLAIM.CLAIMCOST').
            report_var (str): Report by variables.
            by_var (str): Group by variable.
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exposure_type (str): Exposure type (default: 'TIS').
            find_first_fail_flag (bool): Find first fail flag (default: False).
            exp_measurement_type (int): Exposure measurement type (default: 1).
            unique_value (bool): Force unique value (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            tis_point_of_view (str): TIS point of view (default: 'frombuild').
            wrty_time_length (int): Warranty time length (default: 12).
            usage_profile (bool): Usage profile flag (default: False).
            usage_type (str): Usage measurement type (default: 'mileage').
            wrty_usage_max_mileage (int): Warranty max mileage (default: 100000).
            wrty_usage_max_hours (int): Warranty max hours (default: 1000).
            wrty_usage_max_km (str): Warranty max km.
            repair_before_sold (bool): Exclude repairs before selling (default: True).
            horiz_ref_value (bool): Horizontal reference value flag (default: False).
            horiz_ref_label (bool): Horizontal reference label flag (default: False).
            vert_ref_value (bool): Vertical reference value flag (default: False).
            vert_ref_label (bool): Vertical reference label flag (default: False).
            display_grid (bool): Display grid lines (default: False).
            display_type (str): Display type (default: 'CODE').
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_time_of_event_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "BYVAR": by_var,
            "DATADOMAIN": data_domain,
            "EXPOSURETYPE": exposure_type,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "UNIQUEVALUE": "TRUE" if unique_value else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "TISPOINTOFVIEW": tis_point_of_view,
            "WRTYTIMELENGTH": wrty_time_length,
            "USAGEPROFILE": "TRUE" if usage_profile else "FALSE",
            "USAGETYPE": usage_type,
            "WRTYUSAGEMAXMILEAGE": wrty_usage_max_mileage,
            "WRTYUSAGEMAXHOURS": wrty_usage_max_hours,
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "REPAIRBEFORESOLD": "TRUE" if repair_before_sold else "FALSE",
            "HORIZREFVALUE": "TRUE" if horiz_ref_value else "FALSE",
            "HORIZREFLABEL": "TRUE" if horiz_ref_label else "FALSE",
            "VERTREFVALUE": "TRUE" if vert_ref_value else "FALSE",
            "VERTREFLABEL": "TRUE" if vert_ref_label else "FALSE",
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "DISPLAYTYPE": display_type,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="TIMEOFCLAIM_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def run_reliability_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        parent_analysis_id: str = None,  # pyright: ignore
        parent_analysis_owner: str = None,  # pyright: ignore
        analysis_var: str = "RELIABILITYCLAIMCOUNT",
        report_var: str = "",
        by_var: str = "",
        reliab_var: str = "TIS",
        data_domain: str = "PRODUCT,CLAIM,LABOR",
        exp_chart_type: str = "INCREMENTAL",
        projected_values_hours: str = "100,200,300,400,500,600,700,800,900,1000",
        confidence: float = 0.95,
        bin_increment: int = 500,
        display_grid: bool = False,
        exp_measurement_type: int = 1,
        exposure_type: str = "TIS",
        find_exp_measurement: bool = False,
        show_immature_exposure: str = "N",
        seas_sale_lag: bool = False,
        max_by_var: int = 20,
        find_first_fail_flag: bool = True,
        wrty_usage_max_km: str = "",
        user_title: str = "ANALYSISNAME",
        user_subtitle: str = "CREATEDBY",
        user_footnote: str = "CREATEDDATE",
        wait_for_completion: bool = True
    ) -> dict:
        """
        Creates and runs a Reliability Analysis on product/claim reliability data.

        Args:
            name (str): Unique name for the analysis.
            data_selection_id (str): ID of the launched data selection.
            folder_id (str): Optional parent folder/project ID.
            parent_analysis_id (str): Optional parent analysis ID to link alert analysis.
            parent_analysis_owner (str): Optional parent owner to link alert analysis.
            analysis_var (str): Analysis variable (default: 'RELIABILITYCLAIMCOUNT').
            report_var (str): Report by variables.
            by_var (str): Group by variable.
            reliab_var (str): Reliability variable (default: 'TIS').
            data_domain (str): Data domains involved (default: 'PRODUCT,CLAIM,LABOR').
            exp_chart_type (str): Exposure chart type (default: 'INCREMENTAL').
            projected_values_hours (str): Projected values hours list.
            confidence (float): Confidence level (default: 0.95).
            bin_increment (int): Bin increment size (default: 500).
            display_grid (bool): Display grid lines (default: False).
            exp_measurement_type (int): Exposure measurement type (default: 1).
            exposure_type (str): Exposure type (default: 'TIS').
            find_exp_measurement (bool): Find exposure measurement (default: False).
            show_immature_exposure (str): Show immature exposure (default: 'N').
            seas_sale_lag (bool): Seasonal sale lag (default: False).
            max_by_var (int): Max by variable count (default: 20).
            find_first_fail_flag (bool): Find first fail flag (default: True).
            wrty_usage_max_km (str): Warranty max km.
            user_title (str): Custom user title.
            user_subtitle (str): Custom user subtitle.
            user_footnote (str): Custom user footnote.
            wait_for_completion (bool): If True, waits for job completion (default: True).
        """
        logger.info("--- TOOL USED: run_reliability_analysis (%s) ---", name)
        token = await get_token(ctx)
        params = {
            "ANALYSISVAR": analysis_var,
            "REPORTVAR": report_var,
            "BYVAR": by_var,
            "RELIABVAR": reliab_var,
            "DATADOMAIN": data_domain,
            "EXPCHARTTYPE": exp_chart_type,
            "PROJECTEDVALUESHOURS": projected_values_hours,
            "CONFIDENCE": confidence,
            "BININCREMENT": bin_increment,
            "DISPLAYGRID": "TRUE" if display_grid else "FALSE",
            "EXPMEASUREMENTTYPE": exp_measurement_type,
            "EXPOSURETYPE": exposure_type,
            "FINDEXPMEASUREMENT": "TRUE" if find_exp_measurement else "FALSE",
            "SHOWIMMATUREEXPOSURE": show_immature_exposure,
            "SEASSALELAG": "TRUE" if seas_sale_lag else "FALSE",
            "MAXBYVAR": max_by_var,
            "FINDFIRSTFAILFLAG": "TRUE" if find_first_fail_flag else "FALSE",
            "WRTYUSAGEMAXKM": wrty_usage_max_km,
            "USERTITLE": user_title,
            "USERSUBTITLE": user_subtitle,
            "USERFOOTNOTE": user_footnote,
            "PARENT_ANALYSIS_ID": parent_analysis_id,
            "PARENT_ANALYSIS_OWNER": parent_analysis_owner
        }
        return await create_and_run_analysis(
            name=name,
            model_name="RELIABILITY_PRODUCT",
            data_selection_id=data_selection_id,
            token=token,
            folder_id=folder_id,
            parameter_updates=params,
            wait_for_completion=wait_for_completion
        )

    @mcp.tool()
    async def drop_table_from_memory(
        caslib_name: str, table_name: str, ctx: Context
    ) -> dict[str, Any]:
        """Drop a CAS table from memory in the specified caslib.

        Drops both session-scope and global-scope versions of the table from CAS memory,
        which is useful for cleaning up temporary tables or freeing up RAM.

        Args:
            caslib_name: The name of the caslib.
            table_name: The table to drop.
        """
        logger.info("--- TOOL USED: drop_table_from_memory (%s.%s) ---", caslib_name, table_name)
        caslib_name = _validate_sas_identifier(caslib_name, "caslib_name")
        table_name = _validate_sas_identifier(table_name, "table_name")
        token = await get_token(ctx)
        code = f"""
        cas mySession;
        proc cas;
          table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
        quit;
        cas mySession terminate;
        """
        res = await run_one_snippet(code, "drop_table", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": f"Table {caslib_name}.{table_name} dropped from CAS memory."
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to drop table. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def reload_table_to_memory(
        caslib_name: str, table_name: str, ctx: Context
    ) -> dict[str, Any]:
        """Cleanly reload a table from its caslib data source and promote it to global scope.

        Drops any existing session/global scope instances of the table from memory,
        finds its source file (e.g. sashdat) dynamically, and reloads/promotes it to global scope.
        This is highly useful for restoring a clean CAS environment after table corruption or unloading.

        Args:
            caslib_name: The name of the caslib.
            table_name: The table to reload.
        """
        logger.info("--- TOOL USED: reload_table_to_memory (%s.%s) ---", caslib_name, table_name)
        caslib_name = _validate_sas_identifier(caslib_name, "caslib_name")
        table_name = _validate_sas_identifier(table_name, "table_name")
        token = await get_token(ctx)
        code = f"""
        cas mySession;
        proc cas;
          table.fileInfo r=f / caslib="{caslib_name}";
          src_file = "";
          do row over f.FileInfo;
            if (upcase(scan(row.Name, 1, '.')) == upcase("{table_name}")) then do;
              src_file = row.Name;
            end;
          end;
          if (src_file == "") then src_file = "{table_name}.sashdat";
          
          table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
          table.loadTable / 
            caslib="{caslib_name}" 
            path=src_file 
            casout={{caslib="{caslib_name}" name="{table_name}" promote=true}};
        quit;
        cas mySession terminate;
        """
        res = await run_one_snippet(code, "reload_table", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": f"Table {caslib_name}.{table_name} successfully reloaded and promoted in CAS."
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to reload table. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def reload_fqa_metadata_tool(
        fqa_base_path: str,
        ctx: Context
    ) -> dict[str, Any]:
        """
        Reloads the FQA metadata configuration (e.g., column_parameters.csv, analysis_param.csv) 
        into the SAS Analytics for IoT Postgres database without reloading the underlying CAS data.
        This is useful after modifying FQA configuration files.
        Note: This tool may take several minutes to run and could exceed standard tool timeouts, 
        but it will successfully trigger the load in the background.
        
        Args:
            fqa_base_path (str): The absolute Linux path on the CAS server where the FQA Demo_Data_transformed
                                 directory resides
                                 (e.g., "/export/sas-viya/homes/germsz/AIoT/FQA/Demo_Data_transformed").
        """
        logger.info("--- TOOL USED: reload_fqa_metadata_tool (%s) ---", fqa_base_path)
        fqa_base_path = _validate_safe_path(fqa_base_path).rstrip("/")
        token = await get_token(ctx)
        
        code = f"""
        /* Ensure etl=N so we don't wipe data and only load config */
        data _null_;
          infile '{fqa_base_path}/Load_Demo_Data_params.txt' truncover;
          file '{fqa_base_path}/Load_Demo_Data_params.tmp';
          input line $32767.;
          if index(line, 'etl=Y') > 0 or index(line, 'etl = Y') > 0 then line = 'etl=N';
          put line;
        run;

        data _null_;
          infile '{fqa_base_path}/Load_Demo_Data_params.tmp' truncover;
          file '{fqa_base_path}/Load_Demo_Data_params.txt';
          input line $32767.;
          put line;
        run;

        /* Execute the dataload macro */
        %include '{fqa_base_path}/Load_Demo_Data.sas';
        """
        
        res = await run_one_snippet(code, "reload_fqa_metadata", token)
        
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": "FQA Metadata configuration successfully reloaded.",
                "log": res.get("log")
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to reload FQA metadata. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def remediate_high_cardinality_tool(
        caslib_name: str,
        table_name: str,
        column_name: str,
        strategy: str,
        ctx: Context,
        target_column: str | None = None,
    ) -> dict[str, Any]:
        """Remediates high-cardinality columns in a CAS table to make them suitable for standard analyses.

        Supports three strategies:
        - 'binning': Groups the top 10 values by frequency and bins the rest as 'OTHER'.
        - 'temporal': Extracts Year-Month and relative age offsets (requires target_column representing inservice_date).
        - 'target_encoding': Calculates target encoding using the mean of target_column.

        Args:
            caslib_name: Name of the caslib containing the table.
            table_name: Name of the CAS table.
            column_name: Name of the high-cardinality column to remediate.
            strategy: Remediation strategy ('binning', 'temporal', or 'target_encoding').
            target_column: Name of the target variable for target encoding or target inservice_date for temporal.
        """
        logger.info("--- TOOL USED: remediate_high_cardinality (%s.%s.%s) ---", caslib_name, table_name, column_name)
        caslib_name = _validate_sas_identifier(caslib_name, "caslib_name").upper()
        table_name = _validate_sas_identifier(table_name, "table_name").upper()
        column_name = _validate_sas_identifier(column_name, "column_name").upper()
        if target_column:
            target_column = _validate_sas_identifier(target_column, "target_column").upper()
        token = await get_token(ctx)
            
        strategy = strategy.lower()
        if strategy not in ["binning", "temporal", "target_encoding"]:
            return {
                "status": "failed",
                "message": f"Unsupported strategy '{strategy}'. Use 'binning', 'temporal', or 'target_encoding'."
            }
            
        code = f"""
        cas mySession;
        libname mycas CAS sessref=mySession caslib="{caslib_name}";
        """
        
        new_col = ""
        new_desc = ""
        new_label = ""
        new_type = 2
        
        if strategy == "binning":
            new_col = f"{column_name}_BINNED"
            new_desc = f"Binned {column_name} (Top 10 + Other)"
            new_label = f"Binned {column_name}"
            new_type = 2
            
            code += f"""
            proc freq data=mycas.{table_name} order=freq;
                tables {column_name} / out=work.freq_out;
            run;
            
            data mycas.freq_out_top10;
                set work.freq_out(obs=10);
            run;
            
            proc fedsql sessref=mySession;
                create table {caslib_name}.{table_name}_new as
                select t1.*, 
                       case when t2.{column_name} is not null then cast(t1.{column_name} as varchar(256))
                            else 'OTHER'
                       end as {new_col}
                from {caslib_name}.{table_name} as t1
                left join {caslib_name}.freq_out_top10 as t2
                on t1.{column_name} = t2.{column_name};
            quit;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="freq_out_top10" quiet=true;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """
            
        elif strategy == "temporal":
            if not target_column:
                return {
                    "status": "failed",
                    "message": "Strategy 'temporal' requires 'target_column' (the inservice_date column name)."
                }
            new_col = f"{column_name}_AGE_MONTHS"
            new_desc = f"Age in Months from {target_column} to {column_name}"
            new_label = "Age in Months"
            new_type = 4
            
            code += f"""
            data mycas.{table_name}_new(promote=yes);
                set mycas.{table_name};
                length {new_col} 8;
                if {column_name} ne . and {target_column} ne . then do;
                    {new_col} = ({column_name} - {target_column}) / 30.4375;
                end;
                else do;
                    {new_col} = .;
                end;
            run;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """
            
        elif strategy == "target_encoding":
            if not target_column:
                return {
                    "status": "failed",
                    "message": "Strategy 'target_encoding' requires 'target_column' (the dependent/target variable)."
                }
            new_col = f"{column_name}_TE"
            new_desc = f"Target encoded {column_name} against {target_column}"
            new_label = f"Target encoded {column_name}"
            new_type = 4
            
            code += f"""
            proc summary data=mycas.{table_name} nway;
                class {column_name};
                var {target_column};
                output out=work.te_lookup(drop=_type_ _freq_) mean=te_val;
            run;
            
            data mycas.te_lookup;
                set work.te_lookup;
            run;
            
            proc fedsql sessref=mySession;
                create table {caslib_name}.{table_name}_new as
                select t1.*, coalesce(t2.te_val, 0) as {new_col}
                from {caslib_name}.{table_name} as t1
                left join {caslib_name}.te_lookup as t2
                on t1.{column_name} = t2.{column_name};
            quit;
            
            proc cas;
                table.dropTable / caslib="{caslib_name}" name="te_lookup" quiet=true;
                table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
                table.promote / caslib="{caslib_name}" name="{table_name}_new" target="{table_name}";
            quit;
            """

        code += f"""
        libname metapg CAS caslib="AIoTPgMeta" sessref=mySession;
        %macro update_metadata;
            %if %sysfunc(exist(metapg.TABLECOLUMN_META_PG)) and
                %sysfunc(exist(metapg.TABLECOLUMN_ATTRIBUTES_PG))
                %then %do;
                
                /* 1. Copy promoted tables to local WORK tables */
                data work.table_meta_temp;
                    set metapg.TABLECOLUMN_META_PG;
                run;
                data work.table_attr_temp;
                    set metapg.TABLECOLUMN_ATTRIBUTES_PG;
                run;
                
                /* 2. Perform deletes and inserts on local WORK tables */
                proc sql;
                    delete from work.table_meta_temp where column_id = "{new_col}_F999";
                    insert into work.table_meta_temp
                    (column_id, column_nm, table_id, column_data_type_cd,
                     column_desc, column_label_txt, solution_cd, column_fmt_nm)
                    values ("{new_col}_F999", "{new_col}", "{table_name}",
                            {new_type}, "{new_desc}", "{new_label}", "FQA", "");
                    
                    delete from work.table_attr_temp where column_id = "{new_col}_F999";
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_RV", "{new_col}_F999", "REQVAR", "Y", 2);
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values (
                        "{new_col}_F999_AV", 
                        "{new_col}_F999", 
                        "REPORTVAR", 
                        "CROSSTAB,DETAIL,MULTIVARIATE,PARETO,STATDRIVER,TEXTANALYSIS", 
                        2
                    );
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_FT", "{new_col}_F999", "FACT_TABLE", "{table_name}", 2);
                    insert into work.table_attr_temp
                    (tablecolumn_attr_id, column_id, attribute_nm, attribute_val, attribute_data_type_cd)
                    values ("{new_col}_F999_FC", "{new_col}_F999", "FACT_COLUMN", "{new_col}", 2);
                quit;
                
                /* 3. Upload modified WORK tables to CAS session-scope */
                data metapg.TABLECOLUMN_META_PG_new;
                    set work.table_meta_temp;
                run;
                data metapg.TABLECOLUMN_ATTRIBUTES_PG_new;
                    set work.table_attr_temp;
                run;
                
                /* 4. Drop old promoted tables and promote new ones */
                proc cas;
                    table.dropTable / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_META_PG" 
                        quiet=true;
                    table.dropTable / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_ATTRIBUTES_PG" 
                        quiet=true;
                    table.promote / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_META_PG_new" 
                        target="TABLECOLUMN_META_PG";
                    table.promote / 
                        caslib="AIoTPgMeta" 
                        name="TABLECOLUMN_ATTRIBUTES_PG_new" 
                        target="TABLECOLUMN_ATTRIBUTES_PG";
                quit;
            %end;
        %mend update_metadata;
        %update_metadata;
        cas mySession terminate;
        """
        
        res = await run_one_snippet(code, "remediate", token)
        if res.get("state") == "completed":
            return {
                "status": "success",
                "message": (
                    f"Successfully remediated column {column_name} in "
                    f"{caslib_name}.{table_name} using strategy "
                    f"'{strategy}'. Created column {new_col}."
                ),
                "log": (res.get("log") or "")[:1000]
            }
        else:
            return {
                "status": "failed",
                "message": f"Failed to remediate column. Log: {res.get('log')}"
            }

    @mcp.tool()
    async def create_child_data_selection_and_launch_tool(
        parent_data_selection_id: str,
        new_name: str,
        new_filters: list[dict],
        parent_analysis_id: str,
        ctx: Context,
        folder_id: str | None = None,
        creation_type: str | None = None,
    ) -> dict[str, Any]:
        """Creates a child data selection from a parent data selection
        with new filters and parent links, and launches it in CAS.

        Args:
            parent_data_selection_id (str): The ID of the parent data selection to copy.
            new_name (str): Name for the new child data selection.
            new_filters (list[dict]): List of additional filter criteria to append.
            parent_analysis_id (str): The ID of the parent Decision Tree or analysis to link this child to.
            folder_id (str, optional): The ID of the project folder to add this data selection to.
            creation_type (str, optional): Override the creationType (e.g. 'EIENTERPRISE' for Emerging Issues).
        """
        import uuid
        async with viya_session("create_child_data_selection_and_launch", ctx) as client:
            logger.info("Copying parent data selection %s to '%s'", parent_data_selection_id, new_name)
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_data_selection_id}/copy"
            payload = {"name": new_name}
            if creation_type:
                payload["creationType"] = creation_type
            resp_copy = await client.post(copy_url, json=payload)
            resp_copy.raise_for_status()
            new_ds = resp_copy.json()
            new_ds_id = new_ds["id"]
            
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                headers={"Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")
            
            filter_criteria = ds_details.get("filterCriteria", {})
            group_0 = filter_criteria.get("0", [])
            
            for f in new_filters:
                new_f = {
                    "id": str(uuid.uuid4()),
                    "criteriaGroupId": new_ds_id,
                    "columnName": f.get("columnName"),
                    "operatorCode": f.get("operatorCode", "IN"),
                    "excludeFlag": f.get("excludeFlag", False),
                    "componentTypeCode": f.get("componentTypeCode", f.get("component", "PRODUCT")),
                    "component": f.get("component", "PRODUCT"),
                    "filterAttributeId": f.get(
                        "filterAttributeId", f"{f.get('columnName')}_{f.get('component', 'PRODUCT')}"
                    ),
                    "groupId": "0",
                    "uiDisplay": False,
                    "values": f.get("values", [])
                }
                group_0.append(new_f)
            
            ds_details["filterCriteria"] = {"0": group_0}
            ds_details["additionalAttributes"] = [
                {"name": "parentAnalysisId", "value": parent_analysis_id},
                {"name": "PARENT_ANALYSIS_ID", "value": parent_analysis_id}
            ]
            
            headers_put = {
                "Content-Type": "application/vnd.sas.data.selection+json",
                "Accept": "application/vnd.sas.data.selection+json",
                "If-Match": etag
            }
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                json=ds_details,
                headers=headers_put
            )
            resp_put.raise_for_status()
            data_selection_cache.clear()
            
            cols = [
                {"columnName": "PRODUCTION_DATE", "columnNameLabel": "Production Date",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnNameLabel": "Selling Dealer Country",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "MODEL_CD", "columnNameLabel": "Model Code",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_CD", "columnNameLabel": "Selling Dealer Code",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "INSERVICE_DATE", "columnNameLabel": "In Service Date",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "CSTMR_STATE_CD", "columnNameLabel": "Customer State",
                        "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code",
                        "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "CLAIMCOST", "columnNameLabel": "Total Claim Cost",
                        "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "PRIM_LABOR_CD", "columnNameLabel": "Primary Labor Code",
                        "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "EVENT_SUBMIT_DATE", "columnNameLabel": "Claim Submit Date",
                        "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "REPL_PART_CD", "columnNameLabel": "Replaced Part Code",
                        "columnTableName": "PART", "columnTableNameLabel": "Parts"}
            ]
            
            launch_body = {
                "tableName": f"DS_{new_ds_id.replace('-', '_')[:24]}",
                "launchAppName": "CAS",
                "transposeFlag": 0,
                "launchKeyDim": "PRODUCT",
                "launchColumnTables": ["CLAIM", "PART", "PRODUCT"],
                "launchColumns": cols
            }
            
            resp_launch = await client.post(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches",
                json=launch_body,
                headers={
                    "Content-Type": "application/vnd.sas.data.selection.launch+json",
                    "Accept": "application/vnd.sas.data.selection.launch+json"
                }
            )
            resp_launch.raise_for_status()
            launch_id = resp_launch.json()["id"]
            
            poll_interval = 1.0
            deadline = time.monotonic() + 3600.0
            while True:
                resp_status = await client.get(
                    f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches/{launch_id}",
                    headers={"Accept": "application/vnd.sas.data.selection.launch+json"}
                )
                resp_status.raise_for_status()
                launch_status = (resp_status.json().get("status") or "").upper()
                if launch_status == "COMPLETED":
                    break
                if launch_status in ("FAILED", "ERROR", "CANCELED", "CANCELLED", "TIMEDOUT"):
                    raise RuntimeError(f"Data selection launch failed with status {launch_status}")
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"Data selection launch {launch_id} timed out")
                await asyncio.sleep(poll_interval)
                poll_interval = min(poll_interval * 1.5, 10.0)
                
            if folder_id:
                member_body = {
                    "name": new_name,
                    "uri": f"/dataSelection/dataSelections/{new_ds_id}",
                    "contentType": "application/vnd.sas.data.selection",
                    "type": "reference"
                }
                await client.post(
                    f"{VIYA_ENDPOINT}/folders/folders/{folder_id}/members",
                    json=member_body,
                    headers={
                        "Content-Type": "application/vnd.sas.drive.member+json",
                        "Accept": "application/vnd.sas.drive.member+json"
                    }
                )
            
            return {
                "status": "success",
                "data_selection_id": new_ds_id,
                "launch_id": launch_id,
                "message": f"Successfully created and launched child data selection '{new_name}' (ID: {new_ds_id})"
            }

    @mcp.tool()
    async def create_child_analysis_and_run_tool(
        name: str,
        model_name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str | None = None,
        parameter_overrides: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Creates a child analysis instance, configures step parameters with overrides, runs the job,
        and links it in a project folder.

        Args:
            name (str): The name for the new analysis instance.
            model_name (str): The type of analysis model (e.g. `DETAIL_PRODUCT`, `PARETO_PRODUCT`).
            data_selection_id (str): The ID of the data selection to run the analysis on.
            folder_id (str, optional): The ID of the project folder to add this analysis to.
            parameter_overrides (dict, optional): Parameter overrides to update in the analysis step.
        """
        async with viya_session("create_child_analysis_and_run", ctx) as client:
            logger.info("Creating new analysis '%s' on data selection %s", name, data_selection_id)
            analysis_body = {
                "name": name,
                "modelName": model_name,
                "dataSelectionId": data_selection_id
            }
            if folder_id:
                analysis_body["folderID"] = folder_id
                
            collection_body = {
                "name": "analysis",
                "items": [analysis_body]
            }
            
            resp_create = await client.post(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses",
                json=collection_body,
                headers={"Accept": "application/json", "Content-Type": "application/json"}
            )
            resp_create.raise_for_status()
            created_analysis = resp_create.json()["items"][0]
            analysis_id = created_analysis["id"]
            
            resp_full = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                headers={"Accept": "application/vnd.sas.iot.analysis+json"}
            )
            resp_full.raise_for_status()
            full_analysis = resp_full.json()
            analysis_etag = resp_full.headers.get("ETag", "")
            
            steps = full_analysis.get("steps", [])
            if not steps:
                raise RuntimeError("No steps found in the created analysis details")
            step = steps[0]
            step_id = step["id"]
            
            if parameter_overrides:
                params = step.get("inputParameters", [])
                for p in params:
                    pname = p.get("parameterName")
                    if pname in parameter_overrides:
                        p["parameterValue"] = parameter_overrides[pname]
                step["inputParameters"] = params
                full_analysis["steps"] = [step]
                
                resp_put = await client.put(
                    f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                    json=full_analysis,
                    headers={
                        "Content-Type": "application/vnd.sas.iot.analysis+json",
                        "Accept": "application/vnd.sas.iot.analysis+json",
                        "If-Match": analysis_etag
                    }
                )
                resp_put.raise_for_status()
                
            logger.info("Submitting step run job...")
            resp_run = await client.post(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs",
                json={},
                headers={"Accept": "application/json"}
            )
            resp_run.raise_for_status()
            job_link = next(
                (link["href"] for link in resp_run.json().get("links", [])
                 if link.get("rel") == "job"),
                None
            )
            if not job_link:
                raise RuntimeError(
                    f"No job link in run response for analysis {analysis_id} step {step_id}"
                )
            
            poll_interval = 1.0
            deadline = time.monotonic() + 3600.0
            while True:
                resp_job = await client.get(f"{VIYA_ENDPOINT}{job_link}")
                resp_job.raise_for_status()
                job_status = (resp_job.json().get("state") or "").lower()
                if job_status == "completed":
                    break
                if job_status in ("failed", "error", "canceled", "cancelled", "timedout", "timed_out"):
                    try:
                        log_resp = await client.get(f"{VIYA_ENDPOINT}{job_link}/log?limit=1000")
                        log_lines = [item.get("line", "") for item in log_resp.json().get("items", [])]
                        logger.error("Job log output:\n" + "\n".join(log_lines))
                    except Exception:
                        pass
                    raise RuntimeError(f"Analysis job failed with status {job_status}")
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"Analysis job {job_link} timed out")
                await asyncio.sleep(poll_interval)
                poll_interval = min(poll_interval * 1.5, 10.0)
                
            if folder_id:
                member_body = {
                    "name": name,
                    "uri": f"/iotAnalysis/analyses/{analysis_id}",
                    "contentType": "application/vnd.sas.iot.analysis",
                    "type": "reference"
                }
                await client.post(
                    f"{VIYA_ENDPOINT}/folders/folders/{folder_id}/members",
                    json=member_body,
                    headers={
                        "Content-Type": "application/vnd.sas.drive.member+json",
                        "Accept": "application/vnd.sas.drive.member+json"
                    }
                )
                
            return {
                "status": "success",
                "analysis_id": analysis_id,
                "step_id": step_id,
                "message": f"Successfully created and ran child analysis '{name}' (ID: {analysis_id})"
            }





    # ------------------------------------------------------------------
    # Visual Forecasting Tools
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_forecasting_data_definitions(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:  # pyright: ignore
        """List Visual Forecasting data definitions."""
        async with viya_session("list_forecasting_data_definitions", ctx) as client:
            items, count = await _get_paged_items(
                "/forecastingGateway/dataDefinitions", client, limit=limit, start=start
            )
            return {"items": items, "count": count, "start": start, "limit": limit}

    @mcp.tool()
    async def get_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Get details of a specific Visual Forecasting data definition."""
        async with viya_session("get_forecasting_data_definition", ctx) as client:
            return await _get_json(
                f"/forecastingGateway/dataDefinitions/{data_definition_id}", client
            )

    @mcp.tool()
    async def create_forecasting_data_definition(body: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Create a new Visual Forecasting data definition (pass configuration as a JSON string)."""
        async with viya_session("create_forecasting_data_definition", ctx) as client:
            return await _post_json(
                "/forecastingGateway/dataDefinitions", client, body=json.loads(body)
            )

    @mcp.tool()
    async def delete_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> str:  # pyright: ignore
        """Delete a Visual Forecasting data definition."""
        async with viya_session("delete_forecasting_data_definition", ctx) as client:
            await _delete_resource(
                f"/forecastingGateway/dataDefinitions/{data_definition_id}", client
            )
            return f"Deleted data definition {data_definition_id}"

    @mcp.tool()
    async def run_final_forecast(data_definition_id: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Run the final forecast for a data definition."""
        async with viya_session("run_final_forecast", ctx) as client:
            return await _post_json(
                f"/forecastingGateway/dataDefinitions/{data_definition_id}/finalForecast",
                client,
                body={},
            )

    @mcp.tool()
    async def list_forecasting_filters(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:  # pyright: ignore
        """List Visual Forecasting filters."""
        async with viya_session("list_forecasting_filters", ctx) as client:
            items, count = await _get_paged_items(
                "/forecastingGateway/filters", client, limit=limit, start=start
            )
            return {"items": items, "count": count, "start": start, "limit": limit}

    @mcp.tool()
    async def get_forecasting_filter(filter_id: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Get details of a specific Visual Forecasting filter."""
        async with viya_session("get_forecasting_filter", ctx) as client:
            return await _get_json(f"/forecastingGateway/filters/{filter_id}", client)

    @mcp.tool()
    async def get_forecasting_pipeline_results(pipeline_id: str, component_id: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Get the results of a specific component within a forecasting pipeline."""
        async with viya_session("get_forecasting_pipeline_results", ctx) as client:
            return await _get_json(
                f"/forecastingGateway/pipelines/{pipeline_id}/components/{component_id}/results",
                client,
            )

    @mcp.tool()
    async def run_forecasting_comparison(body: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Run a forecasting pipeline comparison (pass configuration as a JSON string)."""
        async with viya_session("run_forecasting_comparison", ctx) as client:
            return await _post_json(
                "/forecastingGateway/comparison", client, body=json.loads(body)
            )

    @mcp.tool()
    async def get_forecasting_comparison_results(ctx: Context = None) -> dict:  # pyright: ignore
        """Get forecasting comparison results."""
        async with viya_session("get_forecasting_comparison_results", ctx) as client:
            return await _get_json("/forecastingGateway/comparison/results", client)

    @mcp.tool()
    async def generate_forecasting_timeseries_plot(body: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Generate a time series plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecasting_timeseries_plot", ctx) as client:
            return await _post_json(
                "/forecastingGateway/timeSeriesPlot", client, body=json.loads(body)
            )

    @mcp.tool()
    async def generate_forecast_plot(body: str, ctx: Context = None) -> dict:  # pyright: ignore
        """Generate a forecast plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecast_plot", ctx) as client:
            return await _post_json(
                "/forecastingGateway/forecastPlot", client, body=json.loads(body)
            )


    @mcp.tool()
    async def list_fqa_data_model_variables_tool(data_selection_id: str, ctx: Context) -> dict:
        """
        Lists the available variables/fields for the FQA data model in a given Data Selection.
        This queries the Data Selection definition and extracts configured launch/filter columns.
        """
        logger.info("--- TOOL USED: list_fqa_data_model_variables (%s) ---", data_selection_id)
        token = await get_token(ctx)
        default_vars = [
            "PRODUCT.MODEL_CD",
            "CLAIM.PRIM_REPL_PART_CD",
            "CLAIM.TOTAL_EVENT_AMT",
            "BUILD_PERIOD",
            "INSERVICE_PERIOD",
        ]
        try:
            ds = await get_data_selection(data_selection_id, token)
        except Exception:
            return {"data_selection_id": data_selection_id, "variables": default_vars}

        discovered: list[str] = []
        for col in ds.get("launchColumns") or ds.get("selectedColumns") or []:
            if isinstance(col, dict):
                tbl = col.get("columnTableName") or col.get("component") or ""
                cname = col.get("columnName") or ""
                if cname:
                    entry = f"{tbl}.{cname}" if tbl else cname
                    if entry not in discovered:
                        discovered.append(entry)
        for group_items in (ds.get("filterCriteria") or {}).values():
            if isinstance(group_items, list):
                for crit in group_items:
                    if isinstance(crit, dict):
                        tbl = crit.get("component") or crit.get("componentTypeCode") or ""
                        cname = crit.get("columnName") or ""
                        if cname:
                            entry = f"{tbl}.{cname}" if tbl else cname
                            if entry not in discovered:
                                discovered.append(entry)
        return {
            "data_selection_id": data_selection_id,
            "variables": discovered or default_vars,
        }

    @mcp.tool()
    async def create_root_emerging_issues_analysis_tool(name: str, data_selection_id: str, base_analysis_id: str, ctx: Context) -> dict:
        """
        Creates a new root Emerging Issues analysis by cloning a base/template analysis and replacing its Data Selection.
        This bypasses the limitation where POST /analyses with EIENTERPRISE_PRODUCT creates an Analyze Alert.
        """
        logger.info("--- TOOL USED: create_root_emerging_issues_analysis_tool (%s) ---", name)
        token = await get_token(ctx)
        async with make_client(token) as client:
            copy_url = f"{VIYA_ENDPOINT}/iotAnalysis/analysisActions/copies?name={name}"
            payload = {"analysisId": base_analysis_id}
            resp = await client.post(copy_url, json=payload, headers={"Accept": "application/vnd.sas.iot.analysis+json"})
            resp.raise_for_status()
            new_analysis = resp.json()
            new_id = new_analysis["id"]
            etag = resp.headers.get("ETag") or new_analysis.get("etag")
            if not etag:
                resp_get = await client.get(
                    f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{new_id}",
                    headers={"Accept": "application/vnd.sas.iot.analysis+json"},
                )
                resp_get.raise_for_status()
                new_analysis = resp_get.json()
                etag = resp_get.headers.get("ETag") or "*"

            new_analysis["dataSelectionId"] = data_selection_id
            update_url = f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{new_id}"
            resp_update = await client.put(
                update_url,
                json=new_analysis,
                headers={
                    "Accept": "application/vnd.sas.iot.analysis+json",
                    "Content-Type": "application/vnd.sas.iot.analysis+json",
                    "If-Match": etag,
                },
            )
            resp_update.raise_for_status()
            return {"id": new_id, "name": name, "dataSelectionId": data_selection_id, "status": "CREATED_AND_UPDATED"}

    @mcp.tool()
    async def analyze_emerging_issue_alert_tool(
        parent_data_selection_id: str,
        parent_analysis_id: str,
        new_ds_name: str,
        new_analysis_name: str,
        folder_id: str,
        new_filters: list[dict],
        ctx: Context,
        ds_description: str = "",
        analysis_description: str = "",
    ) -> dict:
        """
        Executes the 'Analyze Alert' workflow from an Emerging Issues alert.
        This generates both a pure Data Selection (with Creation Type 'Emerging Issues') 
        and an Analysis object linked to it, placed inside a specific Project folder.

        Args:
            parent_data_selection_id (str): The ID of the parent data selection to copy.
            parent_analysis_id (str): The ID of the parent Emerging Issues run.
            new_ds_name (str): The name for the newly generated Data Selection.
            new_analysis_name (str): The name for the newly generated Analysis.
            folder_id (str): The ID of the project folder where the Analysis should reside.
            new_filters (list[dict]): Filter criteria to append for the specific alert.
            ds_description (str, optional): Description for the Data Selection.
            analysis_description (str, optional): Description for the Analysis.
        """
        import uuid
        logger.info("--- TOOL USED: analyze_emerging_issue_alert_tool (%s) ---", new_analysis_name)
        token = await get_token(ctx)
        
        async with viya_session("analyze_emerging_issue_alert", ctx) as client:
            # 1. Copy Data Selection with EIENTERPRISE creation type
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_data_selection_id}/copy"
            payload = {
                "name": new_ds_name,
                "description": ds_description,
                "creationType": "EIENTERPRISE"
            }
            resp_copy = await client.post(copy_url, json=payload)
            resp_copy.raise_for_status()
            new_ds_id = resp_copy.json()["id"]

            # 2. Update the Data Selection with filters and parent linking
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}", 
                headers={"Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")

            filter_criteria = ds_details.get("filterCriteria", {})
            group_0 = filter_criteria.get("0", [])
            for f in new_filters:
                group_0.append({
                    "id": str(uuid.uuid4()),
                    "criteriaGroupId": new_ds_id,
                    "columnName": f["columnName"],
                    "operatorCode": f["operatorCode"],
                    "excludeFlag": False,
                    "componentTypeCode": f["component"],
                    "component": f["component"],
                    "filterAttributeId": f"{f['columnName']}_{f['component']}",
                    "groupId": "0",
                    "uiDisplay": False,
                    "values": f["values"]
                })
            ds_details["filterCriteria"] = {"0": group_0}

            attrs = ds_details.get("additionalAttributes", [])
            attrs.append({"name": "parentAnalysisId", "value": parent_analysis_id})
            ds_details["additionalAttributes"] = attrs

            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}", 
                json=ds_details, 
                headers={"If-Match": etag, "Content-Type": "application/json", "Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_put.raise_for_status()
            data_selection_cache.clear()

            # 3. Create the Analysis Object in the specified folder
            an_body = {
                "name": new_analysis_name,
                "description": analysis_description,
                "modelName": "EIENTERPRISE_PRODUCT",
                "dataSelectionId": new_ds_id,
                "folderID": folder_id,
                "status": "SAVED"  # API forces dummy bookmark to SAVED
            }
            collection_body = {
                "name": "analysis",
                "items": [an_body]
            }
            resp_an = await client.post(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses", 
                json=collection_body, 
                headers={"Accept": "application/json", "Content-Type": "application/json"}
            )
            resp_an.raise_for_status()
            
            created_analysis = resp_an.json()["items"][0]
            analysis_id = created_analysis["id"]

            return {
                "message": "Analyze Alert successfully completed. The analysis object is created with 'SAVED' status (Analyze Alert runs cannot be executed natively).",
                "dataSelectionId": new_ds_id,
                "analysisId": analysis_id
            }

    @mcp.tool()
    async def get_iot_analysis_run_status_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Checks the execution status of a running Emerging Issues or IoT analysis.
        Useful for asynchronously polling long-running jobs without hitting MCP tool timeouts.
        """
        logger.info("--- TOOL USED: get_iot_analysis_run_status_tool (%s) ---", analysis_id)
        token = await get_token(ctx)
        async with make_client(token) as client:
            resp = await client.get(f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}", headers={"Accept": "application/vnd.sas.iot.analysis+json"})
            resp.raise_for_status()
            analysis = resp.json()
            steps = analysis.get("steps", [])
            if not steps:
                return {"status": "NO_STEPS"}
            
            step_id = steps[0]["id"]
            status_url = f"{VIYA_ENDPOINT}/iotAnalysis/analysisActions/status?stepId={step_id}"
            resp_status = await client.get(status_url, headers={"Accept": "application/vnd.sas.iot.analysis.step.summary+json"})
            if resp_status.status_code == 200:
                return resp_status.json()
            return {"status": "UNKNOWN"}


    @mcp.tool()
    async def combine_data_selections_tool(new_name: str, base_ds_id: str, additional_ds_ids: list[str], ctx: Context, description: str = "") -> dict:
        """
        Merges multiple Data Selections into a single new Data Selection by combining their filterCriteria.
        It copies the base Data Selection and merges filter values (using logical OR/IN) for matching column names from the additional Data Selections.
        """
        import uuid
        import asyncio
        logger.info("--- TOOL USED: combine_data_selections_tool (%s) ---", new_name)
        token = await get_token(ctx)
        
        async with viya_session("combine_data_selections", ctx) as client:
            # 1. Copy the base DS
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{base_ds_id}/copy"
            payload = {"name": new_name, "description": description}
            resp_copy = await client.post(copy_url, json=payload, headers={"Accept": "application/vnd.sas.data.selection+json"})
            resp_copy.raise_for_status()
            new_ds_id = resp_copy.json()["id"]

            # 2. Fetch all DS concurrently
            async def get_ds(ds_id):
                r = await client.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{ds_id}", headers={"Accept": "application/vnd.sas.data.selection+json"})
                r.raise_for_status()
                return r.json(), r.headers.get("ETag", "")

            results = await asyncio.gather(*[get_ds(id_) for id_ in [new_ds_id] + additional_ds_ids])
            new_ds_details, etag = results[0]
            additional_dss = [r[0] for r in results[1:]]

            # 3. Merge filters in group '0'
            filter_criteria = new_ds_details.get("filterCriteria", {})
            group_0 = filter_criteria.get("0", [])
            
            for add_ds in additional_dss:
                add_fc = add_ds.get("filterCriteria", {}).get("0", [])
                for f_add in add_fc:
                    # Find matching column in group_0
                    match = next((f for f in group_0 if f["columnName"] == f_add["columnName"] and f.get("component") == f_add.get("component")), None)
                    if match:
                        # Merge values uniquely
                        combined = list(set(match.get("values", []) + f_add.get("values", [])))
                        match["values"] = combined
                    else:
                        # Append new rule entirely
                        new_f = dict(f_add)
                        new_f["id"] = str(uuid.uuid4())
                        new_f["criteriaGroupId"] = new_ds_id
                        group_0.append(new_f)
            
            new_ds_details["filterCriteria"]["0"] = group_0

            # 4. PUT updated DS
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}", 
                json=new_ds_details, 
                headers={"If-Match": etag, "Content-Type": "application/json", "Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_put.raise_for_status()
            data_selection_cache.clear()
            return {"id": new_ds_id, "name": new_name, "status": "CREATED_AND_MERGED"}

    @mcp.tool()
    async def update_data_selection_filters_tool(data_selection_id: str, new_filters: list[dict], ctx: Context) -> dict:
        """
        A generic tool to cleanly add or modify specific filters in an existing Data Selection.
        new_filters should be a list of dicts: [{"columnName": "...", "values": ["..."], "component": "...", "operatorCode": "IN"}]
        """
        import uuid
        logger.info("--- TOOL USED: update_data_selection_filters_tool (%s) ---", data_selection_id)
        token = await get_token(ctx)
        async with viya_session("update_ds_filters", ctx) as client:
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{data_selection_id}", 
                headers={"Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")

            filter_criteria = ds_details.get("filterCriteria", {})
            if "0" not in filter_criteria:
                filter_criteria["0"] = []
            group_0 = filter_criteria["0"]

            for f_add in new_filters:
                match = next((f for f in group_0 if f["columnName"] == f_add["columnName"] and f.get("component") == f_add.get("component")), None)
                if match:
                    match["values"] = f_add.get("values", [])
                    match["operatorCode"] = f_add.get("operatorCode", "IN")
                else:
                    group_0.append({
                        "id": str(uuid.uuid4()),
                        "criteriaGroupId": data_selection_id,
                        "columnName": f_add["columnName"],
                        "operatorCode": f_add.get("operatorCode", "IN"),
                        "excludeFlag": False,
                        "componentTypeCode": f_add.get("component", "CLAIM"),
                        "component": f_add.get("component", "CLAIM"),
                        "filterAttributeId": f"{f_add['columnName']}_{f_add.get('component', 'CLAIM')}",
                        "groupId": "0",
                        "uiDisplay": False,
                        "values": f_add.get("values", [])
                    })
            ds_details["filterCriteria"] = filter_criteria
            
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{data_selection_id}", 
                json=ds_details, 
                headers={"If-Match": etag, "Content-Type": "application/json", "Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_put.raise_for_status()
            data_selection_cache.clear()
            return {"id": data_selection_id, "status": "UPDATED"}

    @mcp.tool()
    async def get_alert_filters_tool(alert_row: dict, ctx: Context = None) -> dict:  # pyright: ignore
        """
        Translates a specific row from an Emerging Issues alert table directly into the exact filterCriteria format needed for Data Selections.
        """
        filters = []
        # Typically FQA uses PRIM_REPL_PART_CD on CLAIM, and MODEL_CD on PRODUCT.
        if "PRIM_REPL_PART_CD" in alert_row:
            filters.append({
                "columnName": "PRIM_REPL_PART_CD",
                "component": "CLAIM",
                "operatorCode": "IN",
                "values": [str(alert_row["PRIM_REPL_PART_CD"])]
            })
        if "MODEL_CD" in alert_row:
            filters.append({
                "columnName": "MODEL_CD",
                "component": "PRODUCT",
                "operatorCode": "IN",
                "values": [str(alert_row["MODEL_CD"])]
            })
        return {"filters": filters}

    @mcp.tool()
    async def get_analysis_execution_capabilities(analysis_id: str, ctx: Context) -> dict:
        """
        Checks an Analysis object's modelName and returns whether it can actually be executed natively via the /jobs endpoint.
        """
        logger.info("--- TOOL USED: get_analysis_execution_capabilities (%s) ---", analysis_id)
        token = await get_token(ctx)
        async with viya_session("get_capabilities", ctx) as client:
            resp = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}", 
                headers={"Accept": "application/vnd.sas.iot.analysis+json"}
            )
            resp.raise_for_status()
            data = resp.json()
            model_name = data.get("modelName", "")
            
            if model_name == "EIENTERPRISE_PRODUCT":
                return {
                    "analysisId": analysis_id,
                    "modelName": model_name,
                    "runnable": False,
                    "reason": "This is a dummy bookmark object created by Analyze Alert. It cannot be run natively."
                }
            return {
                "analysisId": analysis_id,
                "modelName": model_name,
                "runnable": True
            }

    @mcp.tool()
    async def force_delete_fqa_object_tool(data_selection_id: str, ctx: Context) -> dict:
        """
        Forcefully deletes a locked FQA Data Selection by first identifying and deleting any locked child analyses,
        then dropping the Data Selection.
        """
        logger.info("--- TOOL USED: force_delete_fqa_object_tool (%s) ---", data_selection_id)
        token = await get_token(ctx)
        deleted_analyses: list[str] = []
        try:
            analyses_resp = await list_iot_analyses(token, limit=1000)
            for item in analyses_resp.get("items", []):
                if item.get("dataSelectionId") == data_selection_id and item.get("id"):
                    aid = item["id"]
                    await delete_iot_analysis(aid, token)
                    deleted_analyses.append(aid)
        except Exception:
            logger.warning("Could not enumerate/delete child analyses for %s", data_selection_id)
        await delete_data_selection(data_selection_id, token)
        return {
            "status": "FORCE_DELETED",
            "id": data_selection_id,
            "deleted_analyses": deleted_analyses,
        }

    async def _safe_run(coro: Awaitable[Any]) -> Any:
        try:
            return await coro
        except Exception as exc:
            return exc

    @mcp.tool()
    async def fqa_template_descriptive_triage_tool(
        name_prefix: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        analysis_var: str = 'CLAIM.CLAIMCOST',
        by_var: str = 'CLAIM.EVENT_STATUS_CD',
        report_var: str = 'PRODUCT.MODEL_CD',
        data_domain: str = 'PRODUCT,CLAIM,LABOR',
        usage_type: str = 'mileage',
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = '',
        repair_before_sold: bool = True,
        failures: str = 'all',
        maturity_level: str = '',
        min_sample_size: int = 0,
        min_sample_size_type: str = '',
        max_by_var: int = 20,
        num_bars: int = 20,
        calc_method: str = 'ASIS',
        exp_chart_type: str = 'cumulative',
        exp_measurement_type: int = 1,
        exposure_type: str = 'TIS',
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = 'N',
        tis_point_of_view: str = 'frombuild',
        unique_value: bool = False,
        usage_profile: bool = False,
        user_title: str = 'ANALYSISNAME',
        user_subtitle: str = 'CREATEDBY',
        user_footnote: str = 'CREATEDDATE',
        value_var: str = 'ACTUAL_VALUE',
        wait_for_completion: bool = True,
        color_var: str = 'CLAIM.CLAIMCOUNT',
        find_exp_measurement: bool = True,
        max_exp_val: str = '',
        claim_submit_lag: bool = True,
        display_type: str = 'CODE',
        control_charts: bool = True,
        control_limits_type: str = 'SYSTEM',
        display_grid: bool = False,
        ucl: str = '',
        lcl: str = '',
        horiz_ref_value: bool = False,
        horiz_ref_label: bool = False,
        vert_ref_value: bool = False,
        vert_ref_label: bool = False
    ) -> dict:
        """
        Executes Phase 1 of the FQA Best Practice workflow (Descriptive Triage and Spatial-Temporal Filtering).
        Automatically creates Pareto, Geographic, and Trend & Control analyses concurrently.
        """
        pareto = run_pareto_analysis_tool(name=f"{name_prefix}_Pareto", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, by_var=by_var, report_var=report_var, data_domain=data_domain, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, max_by_var=max_by_var, num_bars=num_bars, calc_method=calc_method, exp_chart_type=exp_chart_type, exp_measurement_type=exp_measurement_type, exposure_type=exposure_type, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, tis_point_of_view=tis_point_of_view, unique_value=unique_value, usage_profile=usage_profile, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, value_var=value_var, wait_for_completion=wait_for_completion)
        geographic = run_geographic_analysis_tool(name=f"{name_prefix}_Geographic", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, report_var=report_var, color_var=color_var, data_domain=data_domain, exposure_type=exposure_type, tis_point_of_view=tis_point_of_view, calc_method=calc_method, exp_chart_type=exp_chart_type, exp_measurement_type=exp_measurement_type, find_exp_measurement=find_exp_measurement, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, unique_value=unique_value, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, max_exp_val=max_exp_val, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, claim_submit_lag=claim_submit_lag, display_type=display_type, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, wait_for_completion=wait_for_completion)
        trend = run_trend_analysis_tool(name=f"{name_prefix}_Trend", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, by_var=by_var, report_var=report_var, data_domain=data_domain, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, max_by_var=max_by_var, calc_method=calc_method, exp_measurement_type=exp_measurement_type, exposure_type=exposure_type, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, tis_point_of_view=tis_point_of_view, unique_value=unique_value, usage_profile=usage_profile, control_charts=control_charts, control_limits_type=control_limits_type, display_grid=display_grid, ucl=ucl, lcl=lcl, horiz_ref_value=horiz_ref_value, horiz_ref_label=horiz_ref_label, vert_ref_value=vert_ref_value, vert_ref_label=vert_ref_label, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, wait_for_completion=wait_for_completion)

        async with asyncio.TaskGroup() as tg:
            t1 = tg.create_task(_safe_run(pareto))
            t2 = tg.create_task(_safe_run(geographic))
            t3 = tg.create_task(_safe_run(trend))
        results = [t1.result(), t2.result(), t3.result()]
        return {
            "pareto": str(results[0]) if isinstance(results[0], Exception) else results[0],
            "geographic": str(results[1]) if isinstance(results[1], Exception) else results[1],
            "trend": str(results[2]) if isinstance(results[2], Exception) else results[2]
        }

    @mcp.tool()
    async def fqa_template_algorithmic_segmentation_tool(
        name_prefix: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        analysis_var: str = '',
        report_var: str = 'PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_COUNTRY_CD,CLAIM.EVENT_TYPE_CD,CLAIM.EVENT_STATUS_CD',
        data_domain: str = 'PRODUCT,CLAIM,LABOR',
        alpha_level: float = 0.05,
        max_report_level: int = 500,
        area_of_opportunity_unit: int = 1,
        display_grid: bool = False,
        usage_type: str = 'mileage',
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = '',
        repair_before_sold: bool = True,
        failures: str = 'all',
        maturity_level: str = '',
        max_exp_val: str = '',
        min_sample_size: int = 0,
        min_sample_size_type: str = '',
        exp_measurement_type: int = 1,
        exposure_type: str = 'TIS',
        find_first_fail_flag: bool = False,
        show_immature_exposure: str = 'N',
        tis_point_of_view: str = 'frombuild',
        user_title: str = 'ANALYSISNAME',
        user_subtitle: str = 'CREATEDBY',
        user_footnote: str = 'CREATEDDATE',
        display_type: str = 'CODE',
        wait_for_completion: bool = True,
        max_branch: int = 2,
        max_depth: int = 5,
        leaf_size: float = 0.01,
        min_num_obs: int = 10,
        max_report_var: int = 25,
        exp_chart_type: str = 'cumulative',
        unique_value: bool = False,
        usage_profile: bool = False
    ) -> dict:
        """
        Executes Phase 2 of the FQA Best Practice workflow (Algorithmic Subpopulation Segmentation).
        Automatically creates Statistical Drivers and Decision Tree analyses concurrently.
        """
        statistical = run_statistical_driver_analysis_tool(name=f"{name_prefix}_Statistical", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, report_var=report_var, data_domain=data_domain, alpha_level=alpha_level, max_report_level=max_report_level, area_of_opportunity_unit=area_of_opportunity_unit, display_grid=display_grid, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, max_exp_val=max_exp_val, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, exp_measurement_type=exp_measurement_type, exposure_type=exposure_type, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, tis_point_of_view=tis_point_of_view, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, display_type=display_type, wait_for_completion=wait_for_completion)
        decision = run_decision_tree_analysis_tool(name=f"{name_prefix}_Decision", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, report_var=report_var, data_domain=data_domain, max_branch=max_branch, max_depth=max_depth, leaf_size=leaf_size, alpha_level=alpha_level, min_num_obs=min_num_obs, max_report_level=max_report_level, max_report_var=max_report_var, area_of_opportunity_unit=area_of_opportunity_unit, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, max_exp_val=max_exp_val, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, exp_chart_type=exp_chart_type, exp_measurement_type=exp_measurement_type, exposure_type=exposure_type, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, tis_point_of_view=tis_point_of_view, unique_value=unique_value, usage_profile=usage_profile, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, display_type=display_type, wait_for_completion=wait_for_completion)

        async with asyncio.TaskGroup() as tg:
            t1 = tg.create_task(_safe_run(statistical))
            t2 = tg.create_task(_safe_run(decision))
        results = [t1.result(), t2.result()]
        return {
            "statistical": str(results[0]) if isinstance(results[0], Exception) else results[0],
            "decision": str(results[1]) if isinstance(results[1], Exception) else results[1]
        }

    @mcp.tool()
    async def fqa_template_validation_and_forecasting_tool(
        name_prefix: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,  # pyright: ignore
        analysis_var: str = 'PART.REPL_PART_AMT',
        report_var: str = 'PART.REPL_PART_CD',
        data_domain: str = 'PRODUCT,CLAIM,PART',
        rv_dim_column: str = 'PART.REPL_PART_CD',
        threshold_slider_variable: str = 'CONF',
        xvar1: str = 'iotIncr',
        dmdb_max_lev: int = 100001,
        chart_scaling_factor: int = 400,
        node_tip: str = 'CODE',
        node_size: str = 'UNIFORM',
        bin_increment: int = 500,
        rv_table_name_key: str = 'PART.REPL_PART_CD',
        rv_table_name_value: str = 'PART.REPL_PART_CD',
        rv_table_name: str = 'PART.REPL_PART_CD',
        exposure_type: str = 'TIS',
        find_first_fail_flag: bool = False,
        link_tip: str = 'DESC',
        link_value_variable: str = 'conf',
        link_width: str = 'UNIFORM',
        link_width_variable: str = 'count',
        max_link_number: int = 2000,
        max_link_width: int = 3,
        max_node_number: int = 300,
        min_items: int = 2,
        nodesize_variable: str = 'count',
        min_conf_passoc: float = 1.0,
        bin_length: int = 30,
        onetrvruledsflag: int = 0,
        pseudoliftincludeflag: str = 'N',
        sas_file: int = 1,
        seq_proc_threshold: int = 301,
        show_immature_exposure: str = 'N',
        threshold_slider_scale_type: str = 'PERCENTILE',
        assoc_table_threshold: int = 100,
        trule_end_start_flag: str = 'ALL',
        uniform_link_width: int = 1,
        rule_type: str = 'TYPE4',
        perform_repeat_repair: bool = False,
        wrty_usage_max_mileage: int = 100000,
        wrty_usage_max_hours: int = 1000,
        wrty_usage_max_km: str = '',
        repair_before_sold: bool = True,
        failures: str = 'all',
        maturity_level: str = '',
        max_exp_val: str = '',
        max_inter_oc_time: int = 3,
        min_conf_p: str = '',
        min_lift: str = '',
        min_cost: int = 15000,
        no_rules_to_display: str = '',
        yvar2: str = 'CONF',
        yvar1: str = 'SUPPORT',
        xvar2: str = 'iotIncr',
        rule_filter_criteria: str = 'support',
        tis_point_of_view: str = 'frombuild',
        apply_int_oc_time_incr: bool = False,
        apply_rule_st_criteria: bool = True,
        min_support_type: str = 'percent',
        rule_size: str = '1-1,1-2,2-1,2-2',
        min_support_p: float = 0.01,
        min_support_c: int = 1,
        display_type: str = 'CODE',
        user_title: str = 'ANALYSISNAME',
        user_subtitle: str = 'CREATEDBY',
        user_footnote: str = 'CREATEDDATE',
        wait_for_completion: bool = True,
        by_var: str = '',
        calc_method: str = 'ASIS',
        exp_chart_type: str = 'cumulative',
        exp_measurement_type: int = 1,
        find_exp_measurement: bool = True,
        unique_value: bool = True,
        usage_profile: bool = False,
        usage_type: str = 'mileage',
        min_sample_size: int = 0,
        min_sample_size_type: str = '',
        claim_submit_lag: bool = True,
        display_grid: bool = False,
        reliab_var: str = 'TIS',
        projected_values_hours: str = '100,200,300,400,500,600,700,800,900,1000',
        confidence: float = 0.95,
        seas_sale_lag: bool = False,
        max_by_var: int = 20
    ) -> dict:
        """
        Executes Phases 3 & 4 of the FQA Best Practice workflow (Validation, Normalization, and Predictive Forecasting).
        Automatically creates Failure Relationships, Exposure, and Reliability analyses concurrently.
        """
        failure = run_failure_relationships_analysis_tool(name=f"{name_prefix}_Failure", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, report_var=report_var, data_domain=data_domain, rv_dim_column=rv_dim_column, threshold_slider_variable=threshold_slider_variable, xvar1=xvar1, dmdb_max_lev=dmdb_max_lev, chart_scaling_factor=chart_scaling_factor, node_tip=node_tip, node_size=node_size, bin_increment=bin_increment, rv_table_name_key=rv_table_name_key, rv_table_name_value=rv_table_name_value, rv_table_name=rv_table_name, exposure_type=exposure_type, find_first_fail_flag=find_first_fail_flag, link_tip=link_tip, link_value_variable=link_value_variable, link_width=link_width, link_width_variable=link_width_variable, max_link_number=max_link_number, max_link_width=max_link_width, max_node_number=max_node_number, min_items=min_items, nodesize_variable=nodesize_variable, min_conf_passoc=min_conf_passoc, bin_length=bin_length, onetrvruledsflag=onetrvruledsflag, pseudoliftincludeflag=pseudoliftincludeflag, sas_file=sas_file, seq_proc_threshold=seq_proc_threshold, show_immature_exposure=show_immature_exposure, threshold_slider_scale_type=threshold_slider_scale_type, assoc_table_threshold=assoc_table_threshold, trule_end_start_flag=trule_end_start_flag, uniform_link_width=uniform_link_width, rule_type=rule_type, perform_repeat_repair=perform_repeat_repair, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, max_exp_val=max_exp_val, max_inter_oc_time=max_inter_oc_time, min_conf_p=min_conf_p, min_lift=min_lift, min_cost=min_cost, no_rules_to_display=no_rules_to_display, yvar2=yvar2, yvar1=yvar1, xvar2=xvar2, rule_filter_criteria=rule_filter_criteria, tis_point_of_view=tis_point_of_view, apply_int_oc_time_incr=apply_int_oc_time_incr, apply_rule_st_criteria=apply_rule_st_criteria, min_support_type=min_support_type, rule_size=rule_size, min_support_p=min_support_p, min_support_c=min_support_c, display_type=display_type, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, wait_for_completion=wait_for_completion)
        exposure = run_exposure_analysis_tool(name=f"{name_prefix}_Exposure", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, by_var=by_var, data_domain=data_domain, exposure_type=exposure_type, tis_point_of_view=tis_point_of_view, calc_method=calc_method, exp_chart_type=exp_chart_type, exp_measurement_type=exp_measurement_type, find_exp_measurement=find_exp_measurement, find_first_fail_flag=find_first_fail_flag, show_immature_exposure=show_immature_exposure, unique_value=unique_value, usage_profile=usage_profile, usage_type=usage_type, wrty_usage_max_mileage=wrty_usage_max_mileage, wrty_usage_max_hours=wrty_usage_max_hours, wrty_usage_max_km=wrty_usage_max_km, repair_before_sold=repair_before_sold, failures=failures, maturity_level=maturity_level, max_exp_val=max_exp_val, min_sample_size=min_sample_size, min_sample_size_type=min_sample_size_type, claim_submit_lag=claim_submit_lag, display_type=display_type, display_grid=display_grid, bin_increment=bin_increment, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, wait_for_completion=wait_for_completion)
        reliability = run_reliability_analysis_tool(name=f"{name_prefix}_Reliability", data_selection_id=data_selection_id, ctx=ctx, folder_id=folder_id, analysis_var=analysis_var, report_var=report_var, by_var=by_var, reliab_var=reliab_var, data_domain=data_domain, exp_chart_type=exp_chart_type, projected_values_hours=projected_values_hours, confidence=confidence, bin_increment=bin_increment, display_grid=display_grid, exp_measurement_type=exp_measurement_type, exposure_type=exposure_type, find_exp_measurement=find_exp_measurement, show_immature_exposure=show_immature_exposure, seas_sale_lag=seas_sale_lag, max_by_var=max_by_var, find_first_fail_flag=find_first_fail_flag, wrty_usage_max_km=wrty_usage_max_km, user_title=user_title, user_subtitle=user_subtitle, user_footnote=user_footnote, wait_for_completion=wait_for_completion)

        async with asyncio.TaskGroup() as tg:
            t1 = tg.create_task(_safe_run(failure))
            t2 = tg.create_task(_safe_run(exposure))
            t3 = tg.create_task(_safe_run(reliability))
        results = [t1.result(), t2.result(), t3.result()]
        return {
            "failure": str(results[0]) if isinstance(results[0], Exception) else results[0],
            "exposure": str(results[1]) if isinstance(results[1], Exception) else results[1],
            "reliability": str(results[2]) if isinstance(results[2], Exception) else results[2]
        }

    @mcp.tool()
    async def triage_emerging_issue_runs_tool(
        ctx: Context,
        analysis_ids: list[str] | None = None,
        name_filter: str | None = None,
        status_filter: str = "Completed",
        created_by_filter: str | None = None,
        data_selection_id_filter: str | None = None,
        run_sort_by: str = "max_score",
        run_sort_order: str = "desc",
        runs_start: int = 0,
        runs_limit: int = 10,
        alert_sort_by: str = "score",
        alert_sort_order: str = "desc",
        alerts_start: int = 0,
        alerts_limit: int = 10,
        alert_type: str | None = None,
        model_cd: str | None = None,
        target_run_id: str | None = None,
    ) -> dict:
        """
        Bundled FQA Phase 0 triage tool: evaluates all Emerging Issue runs and their alert tables in ONE single
        CAS/SAS Compute backend call, ranks runs by `run_sort_by` (default: 'max_score' descending with automatic
        `lastRunDate` descending tie-breaking so the newest run wins when scores are tied), and returns
        the top `runs_limit` (default: 10) runs plus the top `alerts_limit` (default: 10) sorted alerts for the
        winning (or `target_run_id`) run with pagination metadata (`has_more`, `remaining_count`, `next_start`).

        Args:
            analysis_ids (list[str], optional): Explicit list of Emerging Issue run IDs to inspect. If omitted,
                automatically discovers Emerging Issue runs matching `name_filter` and `status_filter`.
            name_filter (str, optional): Case-insensitive substring filter on run name.
            status_filter (str): Case-insensitive substring filter on run status
                (default: 'Completed'; pass '' for all).
            created_by_filter (str, optional): Case-insensitive substring filter on run creator (`createdBy`).
            data_selection_id_filter (str, optional): Filter runs that share a specific `dataSelectionId` lineage.
            run_sort_by (str): Criterion to rank runs: 'max_score' (default), 'max_cost_score', 'total_alerts',
                'max_acceleration_ap', 'max_acceleration', 'sum_score', 'sum_cost_score', or 'lastRunDate'.
            run_sort_order (str): Sort direction for runs: 'desc' (default) or 'asc'.
            runs_start (int): Offset for the ranked runs list (default: 0).
            runs_limit (int): Maximum number of ranked runs to return (default: 10).
            alert_sort_by (str): Criterion to sort alerts of the top/selected run (default: 'score'; also supports
                'cost_score', 'Events', 'Acceleration_AP', 'Acceleration', 'alert_id').
            alert_sort_order (str): Sort direction for alerts: 'desc' (default) or 'asc'.
            alerts_start (int): Offset for the alerts list (default: 0).
            alerts_limit (int): Maximum number of alerts to return (default: 10).
            alert_type (str, optional): Optional filter on alert_type (e.g., 'PRODUCTIONPERIOD', 'TIMEINSERVICE').
            model_cd (str, optional): Optional filter on model_cd.
            target_run_id (str, optional): Specific run ID whose sorted alerts should be returned. Defaults to the
                #1 highest-ranked run according to `run_sort_by`.
        """
        logger.info("--- TOOL USED: triage_emerging_issue_runs_tool ---")
        token = await get_token(ctx)

        # 1. Discover candidate Emerging Issue runs
        candidate_runs: list[dict[str, Any]] = []
        if analysis_ids:
            for aid in analysis_ids:
                candidate_runs.append({"id": aid})
        else:
            current_start = 0
            fetch_limit = 100
            all_items: list[dict[str, Any]] = []
            while True:
                raw_data = await list_iot_analyses(token, start=current_start, limit=fetch_limit)
                items = raw_data.get("items", [])
                all_items.extend(items)
                if len(items) < fetch_limit:
                    break
                current_start += fetch_limit

            for item in all_items:
                mname = str(item.get("modelName") or "").upper()
                rname = str(item.get("name") or "").upper()
                if not ("EI" in mname or "EMERGING" in mname or "EMERGING" in rname):
                    continue
                if name_filter and name_filter.lower() not in str(item.get("name") or "").lower():
                    continue
                if status_filter and status_filter.lower() not in str(item.get("status") or "").lower():
                    continue
                candidate_runs.append(item)

        if not candidate_runs:
            empty_runs = _paginate_sorted_items(
                [],
                start=runs_start,
                limit=runs_limit,
                sort_by=run_sort_by,
                sort_order=run_sort_order,
                item_label="Emerging Issue runs",
            )
            empty_alerts = _paginate_sorted_items(
                [],
                start=alerts_start,
                limit=alerts_limit,
                sort_by=alert_sort_by,
                sort_order=alert_sort_order,
                item_label="alerts",
            )
            return {
                "top_run": None,
                "runs": empty_runs,
                "selected_run_alerts": empty_alerts,
            }

        # 2. Fetch full analysis definitions concurrently to resolve shortId for each run
        detailed_runs: dict[str, dict[str, Any]] = {}

        async def _fetch_run_detail(run_meta: dict[str, Any]) -> None:
            rid = str(run_meta.get("id") or "")
            if not rid:
                return
            try:
                detail = await get_iot_analysis(rid, token)
                merged = dict(run_meta)
                merged.update(detail)
                detailed_runs[rid] = merged
            except Exception:
                detailed_runs[rid] = dict(run_meta)

        async with asyncio.TaskGroup() as tg:
            for r in candidate_runs:
                tg.create_task(_fetch_run_detail(r))

        if created_by_filter or data_selection_id_filter:
            filtered_runs: dict[str, dict[str, Any]] = {}
            for rid, rmeta in detailed_runs.items():
                if created_by_filter and created_by_filter.lower() not in str(rmeta.get("createdBy") or "").lower():
                    continue
                if (
                    data_selection_id_filter
                    and data_selection_id_filter.lower() not in str(rmeta.get("dataSelectionId") or "").lower()
                ):
                    continue
                filtered_runs[rid] = rmeta
            detailed_runs = filtered_runs

        if not detailed_runs:
            empty_runs = _paginate_sorted_items(
                [],
                start=runs_start,
                limit=runs_limit,
                sort_by=run_sort_by,
                sort_order=run_sort_order,
                item_label="Emerging Issue runs",
            )
            empty_alerts = _paginate_sorted_items(
                [],
                start=alerts_start,
                limit=alerts_limit,
                sort_by=alert_sort_by,
                sort_order=alert_sort_order,
                item_label="alerts",
            )
            return {
                "top_run": None,
                "runs": empty_runs,
                "selected_run_alerts": empty_alerts,
            }

        # 3. Build ONE bundled SAS snippet that exports all runs' _ALERTS_<shortId> tables in a single CAS session
        macro_calls: list[str] = []
        run_short_map: dict[str, str] = {}
        for idx, (rid, rmeta) in enumerate(detailed_runs.items()):
            short_id = str(rmeta.get("shortId") or rid.split("-")[0]).strip()
            safe_short = _validate_sas_identifier(short_id, "short_id")
            model_name = str(rmeta.get("modelName") or "EIENTERPRISE_PRODUCT")
            prefix = model_name.split("_")[0] if "_" in model_name else model_name
            default_tbl = _validate_sas_identifier(f"{prefix}_ALERTS_{safe_short}".upper(), "table")
            run_short_map[rid] = safe_short
            macro_calls.append(f'%_dump_run_alerts(idx={idx}, short_id={safe_short}, default_tbl={default_tbl});')

        index_to_run_id = {idx: rid for idx, rid in enumerate(detailed_runs.keys())}
        bundled_sas_code = f"""
        cas mySession;
        libname mycas cas caslib="QASANLOUT" sessref=mySession;

        proc cas;
          table.tableInfo r=t / caslib="QASANLOUT";
          create data work._qasanlout_tables from t.TableInfo;
        quit;

        %macro _dump_run_alerts(idx=, short_id=, default_tbl=);
          %local matched_tbl;
          %let matched_tbl = &default_tbl;
          %if %sysfunc(exist(work._qasanlout_tables)) %then %do;
            proc sql noprint;
              select upcase(strip(Name)) into :matched_tbl trimmed
              from work._qasanlout_tables
              where index(upcase(Name), upcase("_ALERTS_&short_id")) > 0;
            quit;
          %end;

          %if %sysfunc(exist(mycas.&matched_tbl)) %then %do;
            filename j&idx temp;
            proc json out=j&idx pretty;
              export mycas.&matched_tbl;
            run;
            data _null_;
              infile j&idx;
              if _n_ = 1 then put "BUNDLE_RUN_START:&idx:&matched_tbl";
              input;
              put "BUNDLE_JSON:&idx: " _infile_;
            run;
          %end;
          %else %do;
            data _null_;
              put "BUNDLE_RUN_EMPTY:&idx:&matched_tbl";
            run;
          %end;
        %mend _dump_run_alerts;

        {chr(10).join(macro_calls)}

        cas mySession terminate;
        """

        export_res = await run_one_snippet(bundled_sas_code, "triage_emerging_issue_runs", token)
        export_log = export_res.get("log", "")

        run_json_lines: dict[int, list[str]] = {idx: [] for idx in index_to_run_id}
        run_matched_table: dict[int, str] = {}
        for line in export_log.splitlines():
            if line.startswith("BUNDLE_RUN_START:") or line.startswith("BUNDLE_RUN_EMPTY:"):
                parts = line.split(":", 2)
                if len(parts) == 3 and parts[1].isdigit():
                    run_matched_table[int(parts[1])] = parts[2].strip()
            elif line.startswith("BUNDLE_JSON:"):
                rest = line[len("BUNDLE_JSON:"):]
                idx_str, _, json_line = rest.partition(": ")
                if idx_str.isdigit() and int(idx_str) in run_json_lines:
                    run_json_lines[int(idx_str)].append(json_line)

        alerts_by_run: dict[str, list[dict[str, Any]]] = {}
        run_summaries: list[dict[str, Any]] = []

        for idx, rid in index_to_run_id.items():
            rmeta = detailed_runs[rid]
            raw_json = "\n".join(run_json_lines.get(idx, []))
            raw_alerts: list[dict[str, Any]] = []
            if raw_json.strip():
                try:
                    parsed = json.loads(raw_json)
                    for k, v in parsed.items():
                        if k.startswith("SASTableData") and isinstance(v, list):
                            raw_alerts = v
                            break
                except Exception:
                    logger.warning("Failed to parse bundled alerts JSON for run %s", rid)

            annotated_alerts = [_annotate_fqa_alert(a) for a in raw_alerts]
            alerts_by_run[rid] = annotated_alerts

            scores = [
                float(v) for a in annotated_alerts
                if (v := _extract_field_case_insensitive(a, "score")) is not None and v != ""
            ]
            cost_scores = [
                float(v) for a in annotated_alerts
                if (v := _extract_field_case_insensitive(a, "cost_score")) is not None and v != ""
            ]
            acc_aps = [
                float(v) for a in annotated_alerts
                if (v := _extract_field_case_insensitive(a, "Acceleration_AP")) is not None and v != ""
            ]
            accs = [
                float(v) for a in annotated_alerts
                if (v := _extract_field_case_insensitive(a, "Acceleration")) is not None and v != ""
            ]

            top_alert_sorted = _sort_items(annotated_alerts, sort_by=alert_sort_by, sort_order=alert_sort_order)
            top_alert = top_alert_sorted[0] if top_alert_sorted else None

            run_summaries.append({
                "id": rid,
                "shortId": run_short_map.get(rid),
                "name": rmeta.get("name"),
                "modelName": rmeta.get("modelName"),
                "status": rmeta.get("status"),
                "createdBy": rmeta.get("createdBy"),
                "modifiedBy": rmeta.get("modifiedBy"),
                "lastRunDate": rmeta.get("lastRunDate"),
                "dataSelectionId": rmeta.get("dataSelectionId"),
                "alerts_table": run_matched_table.get(idx),
                "total_alerts": len(annotated_alerts),
                "max_score": max(scores) if scores else 0.0,
                "sum_score": sum(scores) if scores else 0.0,
                "max_cost_score": max(cost_scores) if cost_scores else 0.0,
                "sum_cost_score": sum(cost_scores) if cost_scores else 0.0,
                "max_acceleration_ap": max(acc_aps) if acc_aps else None,
                "max_acceleration": max(accs) if accs else None,
                "top_alert_id": _extract_field_case_insensitive(top_alert, "alert_id") if top_alert else None,
                "top_alert_type": _extract_field_case_insensitive(top_alert, "alert_type") if top_alert else None,
                "top_alert_score": _extract_field_case_insensitive(top_alert, "score") if top_alert else None,
            })

        # Pre-sort by lastRunDate descending so ties on primary run_sort_by deterministically pick the newest run
        run_summaries = _sort_items(run_summaries, sort_by="lastRunDate", sort_order="desc")

        paginated_runs = _paginate_sorted_items(
            run_summaries,
            start=runs_start,
            limit=runs_limit,
            sort_by=run_sort_by,
            sort_order=run_sort_order,
            item_label="Emerging Issue runs",
        )
        all_sorted_runs = _sort_items(run_summaries, sort_by=run_sort_by, sort_order=run_sort_order)
        winning_run = all_sorted_runs[0] if all_sorted_runs else None
        chosen_run_id = target_run_id or (winning_run["id"] if winning_run else None)

        chosen_alerts = list(alerts_by_run.get(chosen_run_id, [])) if chosen_run_id else []
        if alert_type:
            chosen_alerts = [
                a for a in chosen_alerts
                if alert_type.lower() in str(_extract_field_case_insensitive(a, "alert_type") or "").lower()
            ]
        if model_cd:
            chosen_alerts = [
                a for a in chosen_alerts
                if model_cd.lower() in str(_extract_field_case_insensitive(a, "model_cd") or "").lower()
            ]

        paginated_alerts = _paginate_sorted_items(
            chosen_alerts,
            start=alerts_start,
            limit=alerts_limit,
            sort_by=alert_sort_by,
            sort_order=alert_sort_order,
            item_label=f"alerts for run {chosen_run_id}",
        )

        return {
            "top_run": winning_run,
            "selected_run_id": chosen_run_id,
            "runs": paginated_runs,
            "selected_run_alerts": paginated_alerts,
        }

    @mcp.tool()
    async def inspect_emerging_issue_alert_context_tool(
        analysis_id: str,
        ctx: Context,
        alert_id: str | None = None,
        start: int = 0,
        limit: int = 10,
        details_sort_by: str = "actual",
        details_sort_order: str = "desc",
        wumkr_sort_by: str = "Events",
        wumkr_sort_order: str = "desc",
    ) -> dict:
        """
        Bundled FQA Phase 0 / Phase 1 4-Question Early Warning Triage tool (`BP 1b, BP 4, BP 9`):
        fetches the target alert plus all 3 companion tables in `QASANLOUT` (`_ALERTS_<shortId>`,
        `_DETAILS_<shortId>` 3rd time dimension / Sales Lag, `_WUMKR_<shortId>` 2D Build × TIS heat-map cells,
        and `_BASELINE_<shortId>` expected baseline curve) in ONE single CAS call.
        Returns a structured 4-question triage summary and top-10 sorted slices with pagination metadata.

        Args:
            analysis_id (str): The unique ID of the Emerging Issue analysis/run.
            alert_id (str, optional): Alert ID to inspect (e.g., 'alert_10'). If omitted, automatically selects
                the highest-scoring alert in the run.
            start (int): Offset for companion table lists (default: 0).
            limit (int): Maximum rows to return per companion table (default: 10).
            details_sort_by (str): Sort column for `_DETAILS_` sales-lag rows (default: 'actual').
            details_sort_order (str): Sort order for `_DETAILS_` rows ('desc' or 'asc').
            wumkr_sort_by (str): Sort column for `_WUMKR_` heat-map cells (default: 'Events').
            wumkr_sort_order (str): Sort order for `_WUMKR_` rows ('desc' or 'asc').
        """
        logger.info("--- TOOL USED: inspect_emerging_issue_alert_context_tool (%s, %s) ---", analysis_id, alert_id)
        token = await get_token(ctx)
        analysis = await get_iot_analysis(analysis_id, token)
        short_id = _validate_sas_identifier(
            str(analysis.get("shortId") or analysis_id.split("-")[0]).strip(),
            "short_id",
        )
        model_name = str(analysis.get("modelName") or "EIENTERPRISE_PRODUCT")
        prefix = _validate_sas_identifier(
            (model_name.split("_")[0] if "_" in model_name else model_name).upper(),
            "prefix",
        )

        sas_code = f"""
        cas mySession;
        libname mycas cas caslib="QASANLOUT" sessref=mySession;

        %macro _export_companion(suffix=, tag=);
          %local tbl;
          %let tbl = {prefix}_&suffix._{short_id};
          %if %sysfunc(exist(mycas.&tbl)) %then %do;
            filename f&tag temp;
            proc json out=f&tag pretty;
              export mycas.&tbl;
            run;
            data _null_;
              infile f&tag;
              input;
              put "CTX_&tag: " _infile_;
            run;
          %end;
        %mend _export_companion;

        %_export_companion(suffix=ALERTS, tag=ALERTS);
        %_export_companion(suffix=DETAILS, tag=DETAILS);
        %_export_companion(suffix=WUMKR, tag=WUMKR);
        %_export_companion(suffix=BASELINE, tag=BASELINE);

        cas mySession terminate;
        """

        res = await run_one_snippet(sas_code, "inspect_emerging_issue_alert_context", token)
        log_text = res.get("log", "")

        def _parse_tagged_table(tag: str) -> list[dict[str, Any]]:
            prefix_str = f"CTX_{tag}: "
            lines = [ln[len(prefix_str):] for ln in log_text.splitlines() if ln.startswith(prefix_str)]
            raw = "\n".join(lines).strip()
            if not raw:
                return []
            try:
                parsed = json.loads(raw)
                for k, v in parsed.items():
                    if k.startswith("SASTableData") and isinstance(v, list):
                        return v
            except Exception:
                logger.warning("Failed to parse %s JSON from SAS log", tag)
            return []

        alerts_rows = [_annotate_fqa_alert(a) for a in _parse_tagged_table("ALERTS")]
        details_rows = _parse_tagged_table("DETAILS")
        wumkr_rows = _parse_tagged_table("WUMKR")
        baseline_rows = _parse_tagged_table("BASELINE")

        if not alerts_rows:
            return {
                "analysis_id": analysis_id,
                "short_id": short_id,
                "alert": None,
                "message": f"No alerts found for run {analysis_id}.",
            }

        target_alert: dict[str, Any] | None = None
        if alert_id:
            for a in alerts_rows:
                if str(_extract_field_case_insensitive(a, "alert_id") or "").lower() == alert_id.lower():
                    target_alert = a
                    break
        if target_alert is None:
            sorted_alerts = _sort_items(alerts_rows, sort_by="score", sort_order="desc")
            target_alert = sorted_alerts[0]

        chosen_alert_id = str(_extract_field_case_insensitive(target_alert, "alert_id") or "")

        def _belongs_to_alert(row: dict[str, Any]) -> bool:
            rid = _extract_field_case_insensitive(row, "alert_id")
            if rid is not None:
                return str(rid).lower() == chosen_alert_id.lower()
            return True

        alert_details = [r for r in details_rows if _belongs_to_alert(r)]
        alert_wumkr = [r for r in wumkr_rows if _belongs_to_alert(r)]
        alert_baseline = [r for r in baseline_rows if _belongs_to_alert(r)]

        # Evaluate 3rd time dimension (Sales Period Since Production / Sales Lag: actual vs C_ijk)
        breaching_lags = 0
        for d in alert_details:
            act = _extract_field_case_insensitive(d, "actual")
            crit = _extract_field_case_insensitive(d, "C_ijk")
            try:
                if act is not None and crit is not None and float(act) > float(crit):
                    breaching_lags += 1
            except (ValueError, TypeError):
                pass

        if not alert_details:
            sales_lag_verdict = "no_details_rows"
        elif breaching_lags > 0:
            sales_lag_verdict = "manufacturing_or_early_release_spike_confirmed"
        else:
            sales_lag_verdict = "within_critical_limits_check_lot_or_seasonal_batching"

        triage_4_questions = {
            "q1_axis_and_failure_mode": {
                "alert_type": _extract_field_case_insensitive(target_alert, "alert_type"),
                "weibull_beta": target_alert.get("weibull_beta"),
                "failure_mode_hint": target_alert.get("failure_mode_hint"),
            },
            "q2_third_time_dimension_sales_lag": {
                "total_lag_periods": len(alert_details),
                "lags_exceeding_critical_C_ijk": breaching_lags,
                "verdict": sales_lag_verdict,
            },
            "q3_heatmap_cell_breadth": {
                "total_wumkr_cells": len(alert_wumkr),
                "baseline_points": len(alert_baseline),
            },
            "q4_small_n_and_edge_check": {
                "events": _extract_field_case_insensitive(target_alert, "Events"),
                "is_small_n": target_alert.get("is_small_n"),
                "score": _extract_field_case_insensitive(target_alert, "score"),
                "cost_score": _extract_field_case_insensitive(target_alert, "cost_score"),
            },
        }

        return {
            "analysis_id": analysis_id,
            "short_id": short_id,
            "alert_id": chosen_alert_id,
            "alert": target_alert,
            "triage_4_questions": triage_4_questions,
            "details_sales_lag": _paginate_sorted_items(
                alert_details,
                start=start,
                limit=limit,
                sort_by=details_sort_by,
                sort_order=details_sort_order,
                item_label=f"sales-lag details rows for {chosen_alert_id}",
            ),
            "wumkr_cells": _paginate_sorted_items(
                alert_wumkr,
                start=start,
                limit=limit,
                sort_by=wumkr_sort_by,
                sort_order=wumkr_sort_order,
                item_label=f"WUMKR heat-map cells for {chosen_alert_id}",
            ),
            "baseline_curve": _paginate_sorted_items(
                alert_baseline,
                start=start,
                limit=limit,
                sort_by="TIS",
                sort_order="asc",
                item_label=f"baseline curve points for {chosen_alert_id}",
            ),
        }

    @mcp.tool()
    async def run_fqa_preflight_checks_tool(
        table_name: str,
        ctx: Context,
        caslib: str = "QASMartStore",
        candidate_vars: list[str] | None = None,
        unit_id_col: str = "PRODUCT_ID",
        code_col: str = "REPL_PART_CD",
        text_col: str = "CLAIM_COMMENT_TXT",
        start: int = 0,
        limit: int = 10,
        sort_by: str = "distinct_levels",
        sort_order: str = "desc",
    ) -> dict:
        """
        Bundled FQA Preflight Validation tool (`knowledge/fqa/references/preflight.md`):
        executes all 4 preflight gates in ONE single CAS call against a launched data selection or QASMartStore table:
        1. Total rows & distinct units (`unit_id_col`).
        2. Distinct cardinality of `candidate_vars` (checking Pareto `<= 50`, ANOM Driver/Tree `2..500`, and
           Phase 3 single-level pinning `< 2`).
        3. Failure Relationships co-occurrence gate (`>= 200` units with >= 2 codes and `>= 20%` multi-code share).
        4. Text Mining non-missing comment count (`>= 50` recommended, `>= 15` minimum).

        Returns top `limit` (default: 10) candidate variables sorted by `sort_by` with pagination metadata.
        """
        logger.info("--- TOOL USED: run_fqa_preflight_checks_tool (%s.%s) ---", caslib, table_name)
        token = await get_token(ctx)
        safe_caslib = _validate_sas_identifier(caslib, "caslib")
        safe_table = _validate_sas_identifier(table_name, "table_name")
        safe_unit = _validate_sas_identifier(unit_id_col, "unit_id_col")
        safe_code = _validate_sas_identifier(code_col, "code_col")
        safe_text = _validate_sas_identifier(text_col, "text_col")

        default_candidates = candidate_vars or [
            "MODEL_CD",
            "PLANT_CD",
            "ENGINE_MODEL_CD",
            "TRANSMISSION_TYPE_CD",
            "CSTMR_COUNTRY_CD",
            "REPL_PART_CD",
            "LABOR_CD",
            "FAULT_CD",
            "SUPPLIER_CD",
            "DEALER_CD",
        ]
        safe_candidates = [_validate_sas_identifier(v.split(".")[-1], "candidate_var") for v in default_candidates]
        quoted_candidates = ", ".join(f'"{v.upper()}"' for v in safe_candidates)

        sas_code = f"""
        cas mySession;
        proc cas;
          table.columnInfo r=ci / table={{caslib="{safe_caslib}", name="{safe_table}"}};
          existing_cols = {{}};
          do row over ci.ColumnInfo;
            existing_cols[upcase(row.Column)] = 1;
          end;

          simple.numRows r=nr / table={{caslib="{safe_caslib}", name="{safe_table}"}};
          total_rows = nr.numrows;
          print "PREFLIGHT_META:TOTAL_ROWS=" total_rows;

          if "{safe_unit.upper()}" in existing_cols then do;
            simple.distinct r=du /
              table={{caslib="{safe_caslib}", name="{safe_table}"}},
              inputs={{"{safe_unit.upper()}"}};
            do drow over du.Distinct;
              print "PREFLIGHT_META:DISTINCT_UNITS=" drow.Naked;
            end;
          end;

          cand_list = {{{quoted_candidates}}};
          actual_cands = {{}};
          idx = 1;
          do c over cand_list;
            if c in existing_cols then do;
              actual_cands[idx] = c;
              idx = idx + 1;
            end;
          end;

          if dim(actual_cands) > 0 then do;
            simple.distinct r=dc / table={{caslib="{safe_caslib}", name="{safe_table}"}}, inputs=actual_cands;
            do crow over dc.Distinct;
              print "PREFLIGHT_VAR:" crow.Column "|" crow.NDistinct "|" crow.NMiss;
            end;
          end;

          if ("{safe_unit.upper()}" in existing_cols) and ("{safe_code.upper()}" in existing_cols) then do;
            fedsql.execDirect r=fr / query="
              select count(*) as total_units,
                     sum(case when n_codes >= 2 then 1 else 0 end) as multi_units
              from (
                select {safe_unit}, count(distinct {safe_code}) as n_codes
                from ""{safe_caslib}"".""{safe_table}""
                where {safe_code} is not null
                group by {safe_unit}
              ) t
            ";
            do frow over fr['Result Set'];
              print "PREFLIGHT_FR:" frow.total_units "|" frow.multi_units;
            end;
          end;

          if "{safe_text.upper()}" in existing_cols then do;
            fedsql.execDirect r=tm / query="
              select count(*) as non_missing_text
              from ""{safe_caslib}"".""{safe_table}""
              where {safe_text} is not null and char_length(trim({safe_text})) >= 5
            ";
            do trow over tm['Result Set'];
              print "PREFLIGHT_TM:" trow.non_missing_text;
            end;
          end;
        quit;
        cas mySession terminate;
        """

        res = await run_one_snippet(sas_code, "run_fqa_preflight_checks", token)
        log_text = res.get("log", "") + "\n" + res.get("listing", "")

        total_rows = 0
        distinct_units: int | None = None
        var_profiles: list[dict[str, Any]] = []
        fr_total_units = 0
        fr_multi_units = 0
        tm_non_missing = 0

        for raw_line in log_text.splitlines():
            line = raw_line.strip()
            if "PREFLIGHT_META:TOTAL_ROWS=" in line:
                val_str = line.split("PREFLIGHT_META:TOTAL_ROWS=", 1)[1].strip()
                with contextlib.suppress(ValueError):
                    total_rows = int(float(val_str))
            elif "PREFLIGHT_META:DISTINCT_UNITS=" in line:
                val_str = line.split("PREFLIGHT_META:DISTINCT_UNITS=", 1)[1].strip()
                with contextlib.suppress(ValueError):
                    distinct_units = int(float(val_str))
            elif "PREFLIGHT_VAR:" in line:
                payload = line.split("PREFLIGHT_VAR:", 1)[1].strip()
                parts = [p.strip() for p in payload.split("|")]
                if len(parts) >= 3:
                    col_name = parts[0]
                    try:
                        n_dist = int(float(parts[1]))
                    except ValueError:
                        n_dist = 0
                    try:
                        n_miss = int(float(parts[2]))
                    except ValueError:
                        n_miss = 0
                    var_profiles.append({
                        "column": col_name,
                        "distinct_levels": n_dist,
                        "missing_count": n_miss,
                        "pinned_single_level": n_dist < 2,
                        "pareto_ready": 2 <= n_dist <= 50,
                        "anom_driver_tree_ready": 2 <= n_dist <= 500,
                        "exceeds_anom_500_cap": n_dist > 500,
                    })
            elif "PREFLIGHT_FR:" in line:
                payload = line.split("PREFLIGHT_FR:", 1)[1].strip()
                parts = [p.strip() for p in payload.split("|")]
                if len(parts) >= 2:
                    with contextlib.suppress(ValueError):
                        fr_total_units = int(float(parts[0]))
                        fr_multi_units = int(float(parts[1]))
            elif "PREFLIGHT_TM:" in line:
                val_str = line.split("PREFLIGHT_TM:", 1)[1].strip()
                with contextlib.suppress(ValueError):
                    tm_non_missing = int(float(val_str))

        multi_pct = (100.0 * fr_multi_units / fr_total_units) if fr_total_units > 0 else 0.0
        pinned_cols = [v["column"] for v in var_profiles if v["pinned_single_level"]]
        over_500_cols = [v["column"] for v in var_profiles if v["exceeds_anom_500_cap"]]

        return {
            "caslib": safe_caslib,
            "table_name": safe_table,
            "population_summary": {
                "total_rows": total_rows,
                "distinct_units": distinct_units,
                "pinned_single_level_columns": pinned_cols,
                "high_cardinality_over_500_columns": over_500_cols,
                "phase3_population_expansion_needed": len(pinned_cols) > 0 or total_rows < 50,
            },
            "failure_relationships_gate": {
                "code_column": safe_code,
                "total_units_with_code": fr_total_units,
                "multi_code_units": fr_multi_units,
                "multi_code_unit_pct": round(multi_pct, 2),
                "ready": fr_multi_units >= 200 and multi_pct >= 20.0,
                "rule": "Requires >= 200 units with >= 2 distinct codes AND >= 20% multi-code unit share.",
            },
            "text_mining_gate": {
                "text_column": safe_text,
                "non_missing_comments": tm_non_missing,
                "ready_recommended_50": tm_non_missing >= 50,
                "ready_minimum_15": tm_non_missing >= 15,
                "rule": "Requires >= 50 non-empty comments (>= 15 absolute floor); expand population if below floor.",
            },
            "candidate_variables": _paginate_sorted_items(
                var_profiles,
                start=start,
                limit=limit,
                sort_by=sort_by,
                sort_order=sort_order,
                item_label=f"candidate variables in {safe_caslib}.{safe_table}",
            ),
        }

    @mcp.tool()
    async def screen_common_cause_candidates_tool(
        analysis_id: str,
        ctx: Context,
        start: int = 0,
        limit: int = 10,
        sort_by: str = "cost_score",
        sort_order: str = "desc",
        quadrant_filter: str | None = None,
        alert_type: str | None = None,
        min_events: int = 5,
    ) -> dict:
        """
        Bundled FQA Common Cause vs. Special Cause 4-Quadrant Screening tool (`knowledge/fqa/references/workflow.md`):
        exports the run's alert/screening table in ONE single CAS call, classifies each component into one of the
        4 FQA screening quadrants using its rate/cost index (`score`, `cost_score`, `Events`) and Weibull slope
        beta (`Acceleration_AP` / `Acceleration`) plus B-life (`T01`, `T05`, `T10`, `T20`, `T25`), and returns the
        top `limit` (default: 10) candidates sorted by `sort_by` with pagination metadata.

        Quadrants:
        - `HIGH_RATE_WEARING_OUT`: High rate/cost + beta > 1.15 (accelerating wear-out / aging accumulation)
        - `HIGH_RATE_INFANT_BATCH`: High rate/cost + beta < 0.85 (early-life / production batch / assembly defect)
        - `CHRONIC_COMMON_CAUSE`: High rate/cost + 0.85 <= beta <= 1.15 (constant-hazard systemic design baseline)
        - `EMERGING_LOW_VOLUME_ACCELERATING`: Lower volume/cost + beta > 1.15 (emerging wear-out to watch)
        - `LOW_PRIORITY_BACKGROUND`: Low volume/cost and non-accelerating
        """
        logger.info("--- TOOL USED: screen_common_cause_candidates_tool (%s) ---", analysis_id)
        raw = await list_alerts_for_run_tool(
            analysis_id=analysis_id,
            ctx=ctx,
            start=0,
            limit=10000,
            alert_type=alert_type,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        all_alerts = raw.get("items", [])
        if not all_alerts:
            return {
                "analysis_id": analysis_id,
                "quadrant_counts": {},
                "candidates": _paginate_sorted_items(
                    [],
                    start=start,
                    limit=limit,
                    sort_by=sort_by,
                    sort_order=sort_order,
                    item_label="Common Cause / Special Cause candidates",
                ),
            }

        scores = sorted(
            float(v) for a in all_alerts
            if (v := _extract_field_case_insensitive(a, "score")) is not None and v != ""
        )
        cost_scores = sorted(
            float(v) for a in all_alerts
            if (v := _extract_field_case_insensitive(a, "cost_score")) is not None and v != ""
        )
        median_score = scores[len(scores) // 2] if scores else 0.0
        median_cost = cost_scores[len(cost_scores) // 2] if cost_scores else 0.0

        screened: list[dict[str, Any]] = []
        quadrant_counts: dict[str, int] = {}

        for alert in all_alerts:
            events_raw = _extract_field_case_insensitive(alert, "Events")
            try:
                events_val = float(events_raw) if events_raw is not None and events_raw != "" else 0.0
            except (ValueError, TypeError):
                events_val = 0.0
            if events_val < min_events:
                continue

            score_val = float(_extract_field_case_insensitive(alert, "score") or 0.0)
            cost_val = float(_extract_field_case_insensitive(alert, "cost_score") or 0.0)
            beta_val = alert.get("weibull_beta")
            is_high_impact = (score_val >= median_score and score_val > 0) or (cost_val >= median_cost and cost_val > 0)

            if beta_val is not None and beta_val > 1.15:
                quadrant = "HIGH_RATE_WEARING_OUT" if is_high_impact else "EMERGING_LOW_VOLUME_ACCELERATING"
            elif beta_val is not None and beta_val < 0.85:
                quadrant = "HIGH_RATE_INFANT_BATCH" if is_high_impact else "LOW_PRIORITY_BACKGROUND"
            else:
                quadrant = "CHRONIC_COMMON_CAUSE" if is_high_impact else "LOW_PRIORITY_BACKGROUND"

            quadrant_counts[quadrant] = quadrant_counts.get(quadrant, 0) + 1
            if quadrant_filter and quadrant_filter.upper() not in quadrant:
                continue

            entry = dict(alert)
            entry["screening_quadrant"] = quadrant
            entry["b_life_summary"] = {
                "T01": _extract_field_case_insensitive(alert, "T01"),
                "T05": _extract_field_case_insensitive(alert, "T05"),
                "T10": _extract_field_case_insensitive(alert, "T10"),
                "T20": _extract_field_case_insensitive(alert, "T20"),
                "T25": _extract_field_case_insensitive(alert, "T25"),
            }
            screened.append(entry)

        return {
            "analysis_id": analysis_id,
            "min_events": min_events,
            "median_score_threshold": median_score,
            "median_cost_score_threshold": median_cost,
            "quadrant_counts": quadrant_counts,
            "candidates": _paginate_sorted_items(
                screened,
                start=start,
                limit=limit,
                sort_by=sort_by,
                sort_order=sort_order,
                item_label=f"screened candidates for run {analysis_id}",
            ),
        }

    @mcp.tool()
    async def evaluate_subpopulation_lift_and_coverage_tool(
        table_name: str,
        alert_where: str,
        hypothesis_where: str,
        ctx: Context,
        caslib: str = "QASMartStore",
        unit_id_column: str = "PRODUCT_ID",
        broad_1d_where: str | None = None,
        candidate_columns: list[str] | None = None,
        start: int = 0,
        limit: int = 10,
        sort_by: str = "distinct_levels",
        sort_order: str = "asc",
    ) -> dict[str, Any]:
        """
        Bundled FQA Root-Cause Verification & Denominator Dilution tool (`Rule 11.1 & 11.2`):
        evaluates a candidate root-cause subpopulation (`hypothesis_where`) against the alert failure
        slice (`alert_where`) and full fleet baseline in ONE single CAS (`proc cas` + `fedsql.execDirect`) call.

        Computes:
        1. Unit-level (`COUNT(DISTINCT PRODUCT_ID)`) failure rates, **Relative Risk / Lift**, and
           **Alert Unit Coverage %** against the FQA `>= 25%` Root-Cause Gate
           (`PRIMARY_ROOT_CAUSE` vs. `CONTRIBUTING_MECHANISM`).
        2. **4-Year / Broad-Window 1D Denominator Dilution (`dilution_factor`)** when `broad_1d_where` is supplied
           (e.g., `CSTMR_STATE_CD = 'US-GA'` across all 4 years vs. the localized Q4 2019 dealer/build cohort),
           explaining why 1D Phase 1 Geographic or Pareto charts can show low aggregate rates while the true
           multi-dimensional cohort rate is an order of magnitude higher.
        3. **Co-Linearity / Pinned Attribute Detection** inside the hypothesis cohort (`distinct_levels == 1`),
           identifying attributes that are 100% determined by the hypothesis filter and therefore do not require
           redundant filter rules in the final consolidated Root-Cause Data Selection.

        Args:
            table_name (str): Launched Data Selection CAS table (e.g. 'DS_80B27C1A_...') or mart table.
            alert_where (str): SQL predicate defining the alert failure event (e.g. "PRIM_REPL_PART_CD = '9-040'").
            hypothesis_where (str): SQL predicate defining the root-cause cohort (e.g. "SELLING_DEALER_CD = 'A01103'").
            caslib (str): CAS library name (default: 'QASMartStore').
            unit_id_column (str): Unique product/vehicle identifier column (default: 'PRODUCT_ID').
            broad_1d_where (str, optional): Broad 1D SQL predicate (e.g. "CSTMR_STATE_CD = 'US-GA'") to quantify
                multi-year 1D denominator dilution relative to `hypothesis_where`.
            candidate_columns (list[str], optional): Candidate attributes to test for co-linearity / single-level
                pinning inside `hypothesis_where`.
            start (int): Offset for the paginated `attribute_profiles` list (default: 0).
            limit (int): Maximum number of `attribute_profiles` entries to return (default: 10).
            sort_by (str): Sort field for `attribute_profiles` (default: 'distinct_levels').
            sort_order (str): Sort direction ('asc' or 'desc', default: 'asc').
        """
        logger.info("--- TOOL USED: evaluate_subpopulation_lift_and_coverage_tool (%s.%s) ---", caslib, table_name)
        token = await get_token(ctx)
        safe_caslib = _validate_sas_identifier(caslib, "caslib")
        safe_table = _validate_sas_identifier(table_name, "table_name")
        safe_unit = _validate_sas_identifier(unit_id_column, "unit_id_column")

        def _sanitize_where(clause: str, label: str) -> str:
            cleaned = (clause or "").strip()
            if not cleaned or ";" in cleaned or '"' in cleaned:
                raise ValueError(f"Invalid or unsafe SQL {label}: {clause!r}")
            return cleaned

        safe_alert_where = _sanitize_where(alert_where, "alert_where")
        safe_hyp_where = _sanitize_where(hypothesis_where, "hypothesis_where")
        safe_broad_where = _sanitize_where(broad_1d_where, "broad_1d_where") if broad_1d_where else None

        cols_to_check = candidate_columns or [
            "MODEL_CD",
            "ENGINE_MODEL",
            "CSTMR_STATE_CD",
            "SELLING_DEALER_CD",
            "SELLING_DEALER_COUNTRY_CD",
            "PRIM_REPL_PART_CD",
            "PRIM_LABOR_CD",
        ]
        safe_cols = [_validate_sas_identifier(c.split(".")[-1], "column") for c in cols_to_check]

        col_checks_sas: list[str] = []
        for idx, c in enumerate(safe_cols):
            col_checks_sas.append(f"""
              if "{c.upper()}" in existing_cols then do;
                fedsql.execDirect r=colr_{idx} / query="
                  select count(distinct {c}) as n_dist,
                         cast(min(cast({c} as varchar(128))) as varchar(128)) as min_val
                  from ""{safe_caslib}"".""{safe_table}""
                  where ({safe_hyp_where}) and {c} is not null
                ";
                do crow over colr_{idx}['Result Set'];
                  print "LIFT_COL:{c}|" crow.n_dist "|" crow.min_val;
                end;
              end;
            """)

        broad_sas = ""
        if safe_broad_where:
            broad_sas = f"""
              fedsql.execDirect r=br / query="
                select count(distinct {safe_unit}) as broad_units,
                       count(distinct case when ({safe_alert_where})
                             then {safe_unit} else null end) as broad_failed_units
                from ""{safe_caslib}"".""{safe_table}""
                where ({safe_broad_where})
              ";
              do brow over br['Result Set'];
                print "LIFT_BROAD:" brow.broad_units "|" brow.broad_failed_units;
              end;
            """

        sas_code = f"""
        cas mySession;
        proc cas;
          table.columnInfo r=ci / table={{caslib="{safe_caslib}", name="{safe_table}"}};
          existing_cols = {{}};
          do row over ci['ColumnInfo'];
            existing_cols = existing_cols + {{upcase(strip(row.Column))}};
          end;

          fedsql.execDirect r=base / query="
            select count(distinct {safe_unit}) as total_units,
                   count(distinct case when ({safe_alert_where}) then {safe_unit} else null end) as alert_units,
                   count(distinct case when ({safe_hyp_where}) then {safe_unit} else null end) as hyp_units,
                   count(distinct case when ({safe_hyp_where}) and ({safe_alert_where})
                         then {safe_unit} else null end) as hyp_alert_units
            from ""{safe_caslib}"".""{safe_table}""
          ";
          do mrow over base['Result Set'];
            print "LIFT_MAIN:" mrow.total_units "|" mrow.alert_units "|" mrow.hyp_units "|" mrow.hyp_alert_units;
          end;

          {broad_sas}
          {chr(10).join(col_checks_sas)}
        quit;
        cas mySession terminate;
        """

        res = await run_one_snippet(sas_code, "evaluate_subpopulation_lift_and_coverage", token)
        log_text = res.get("log", "") + "\n" + res.get("listing", "")

        total_units = 0
        alert_units = 0
        hyp_units = 0
        hyp_alert_units = 0
        broad_units: int | None = None
        broad_failed_units: int | None = None
        attr_profiles: list[dict[str, Any]] = []

        for raw_line in log_text.splitlines():
            line = raw_line.strip()
            if "LIFT_MAIN:" in line:
                payload = line.split("LIFT_MAIN:", 1)[1].strip()
                parts = [p.strip() for p in payload.split("|")]
                if len(parts) >= 4:
                    with contextlib.suppress(ValueError):
                        total_units = int(float(parts[0]))
                        alert_units = int(float(parts[1]))
                        hyp_units = int(float(parts[2]))
                        hyp_alert_units = int(float(parts[3]))
            elif "LIFT_BROAD:" in line:
                payload = line.split("LIFT_BROAD:", 1)[1].strip()
                parts = [p.strip() for p in payload.split("|")]
                if len(parts) >= 2:
                    with contextlib.suppress(ValueError):
                        broad_units = int(float(parts[0]))
                        broad_failed_units = int(float(parts[1]))
            elif "LIFT_COL:" in line:
                payload = line.split("LIFT_COL:", 1)[1].strip()
                parts = [p.strip() for p in payload.split("|")]
                if len(parts) >= 2:
                    col_name = parts[0]
                    try:
                        n_dist = int(float(parts[1]))
                    except ValueError:
                        n_dist = 0
                    pinned_val = parts[2] if len(parts) >= 3 and n_dist == 1 else None
                    attr_profiles.append({
                        "column": col_name,
                        "distinct_levels": n_dist,
                        "co_linear_pinned": n_dist == 1,
                        "pinned_value": pinned_val,
                        "filter_recommendation": (
                            f"OMIT_REDUNDANT_FILTER (already 100% pinned to '{pinned_val}')"
                            if n_dist == 1
                            else "ORTHOGONAL_CANDIDATE"
                        ),
                    })

        baseline_rate_pct = (100.0 * alert_units / total_units) if total_units > 0 else 0.0
        cohort_rate_pct = (100.0 * hyp_alert_units / hyp_units) if hyp_units > 0 else 0.0
        lift_vs_baseline = (cohort_rate_pct / baseline_rate_pct) if baseline_rate_pct > 0 else 0.0
        coverage_pct = (100.0 * hyp_alert_units / alert_units) if alert_units > 0 else 0.0
        passes_25pct_gate = coverage_pct >= 25.0

        if passes_25pct_gate and lift_vs_baseline >= 2.0:
            verdict = "PRIMARY_ROOT_CAUSE"
        elif lift_vs_baseline > 1.0 and hyp_alert_units > 0:
            verdict = "CONTRIBUTING_MECHANISM"
        else:
            verdict = "NO_EXCESS_RISK"

        dilution_analysis: dict[str, Any] | None = None
        if safe_broad_where and broad_units is not None and broad_failed_units is not None:
            broad_rate_pct = (100.0 * broad_failed_units / broad_units) if broad_units > 0 else 0.0
            dilution_factor = (cohort_rate_pct / broad_rate_pct) if broad_rate_pct > 0 else 0.0
            dilution_analysis = {
                "broad_1d_where": safe_broad_where,
                "broad_1d_units": broad_units,
                "broad_1d_failed_units": broad_failed_units,
                "broad_1d_failure_rate_pct": round(broad_rate_pct, 2),
                "hypothesis_cohort_failure_rate_pct": round(cohort_rate_pct, 2),
                "dilution_factor": round(dilution_factor, 2),
                "ui_explanation": (
                    f"In a 1D multi-year view ({safe_broad_where}), the denominator spans {broad_units} units "
                    f"across the full time window, diluting the apparent failure rate to {broad_rate_pct:.2f}% "
                    f"({broad_failed_units}/{broad_units}). Within the multi-dimensional cohort ({safe_hyp_where}), "
                    f"the true failure rate is {cohort_rate_pct:.2f}% ({hyp_alert_units}/{hyp_units}) — "
                    f"a {dilution_factor:.1f}x denominator dilution effect."
                ),
            }

        co_linear_cols = [
            {"column": a["column"], "pinned_value": a["pinned_value"]}
            for a in attr_profiles
            if a["co_linear_pinned"]
        ]
        orthogonal_cols = [a["column"] for a in attr_profiles if a["distinct_levels"] >= 2]

        return {
            "caslib": safe_caslib,
            "table_name": safe_table,
            "baseline_metrics": {
                "total_units": total_units,
                "alert_failed_units": alert_units,
                "baseline_failure_rate_pct": round(baseline_rate_pct, 3),
            },
            "hypothesis_metrics": {
                "hypothesis_where": safe_hyp_where,
                "cohort_units": hyp_units,
                "cohort_alert_failed_units": hyp_alert_units,
                "cohort_failure_rate_pct": round(cohort_rate_pct, 2),
                "lift_vs_baseline": round(lift_vs_baseline, 2),
                "alert_unit_coverage_pct": round(coverage_pct, 2),
                "passes_25pct_root_cause_gate": passes_25pct_gate,
                "verdict": verdict,
            },
            "denominator_dilution_analysis": dilution_analysis,
            "co_linear_pinned_attributes": co_linear_cols,
            "orthogonal_attributes": orthogonal_cols,
            "attribute_profiles": _paginate_sorted_items(
                attr_profiles,
                start=start,
                limit=limit,
                sort_by=sort_by,
                sort_order=sort_order,
                item_label=f"cohort attributes in {safe_caslib}.{safe_table}",
            ),
        }

    @mcp.tool()
    async def synthesize_root_cause_data_selection_tool(
        parent_data_selection_id: str,
        new_name: str,
        filters: list[dict[str, Any]],
        ctx: Context,
        description: str = "",
        start_date: str | None = None,
        end_date: str | None = None,
        date_type: str = "PRODUCTION_DATE",
        parent_analysis_id: str | None = None,
        folder_id: str | None = None,
        creation_type: str | None = None,
        create_verification_detail_table: bool = True,
        create_verification_pareto: bool = False,
        pareto_report_var: str = "CLAIM.PRIM_LABOR_CD",
    ) -> dict[str, Any]:
        """
        Bundled FQA Root-Cause Synthesis & UI Verification tool (`Rule 11.2`):
        creates ONE and ONLY ONE consolidated Root-Cause Data Selection from a parent Data Selection,
        applies multi-domain orthogonal filters (`PRODUCT`, `CLAIM`, `LABOR`, `PART`) plus optional
        `start_date` / `end_date` (`date_type`), launches the Data Selection into CAS (`DS_<id>`),
        links it into the FQA Project folder (`folder_id`), and optionally creates + runs a verification
        **Details Table (`DETAIL_PRODUCT`)** and/or **Pareto Analysis (`PARETO_PRODUCT`)** so the FQA UI
        immediately reflects the agent's root-cause story.

        Args:
            parent_data_selection_id (str): The ID of the parent Data Selection to clone.
            new_name (str): Name for the single consolidated Root-Cause Data Selection.
            filters (list[dict]): Orthogonal multi-domain filter definitions, e.g.
                `[{"columnName": "MODEL_CD", "component": "PRODUCT", "operatorCode": "IN", "values": ["Galacto"]}]`.
            description (str, optional): Root-cause summary description stored on the Data Selection.
            start_date (str, optional): Optional start date in `YYYY-MM-DD` format (e.g. '2019-10-01').
            end_date (str, optional): Optional end date in `YYYY-MM-DD` format (e.g. '2019-12-31').
            date_type (str): Date dimension when `start_date`/`end_date` are provided (default: 'PRODUCTION_DATE').
            parent_analysis_id (str, optional): Optional parent analysis ID to record in `additionalAttributes`.
            folder_id (str, optional): Project folder ID where the consolidated Data Selection and verification
                analyses should be linked.
            creation_type (str, optional): Optional creationType override (e.g. 'EIENTERPRISE').
            create_verification_detail_table (bool): When True and `folder_id` is provided, automatically creates
                and runs a `DETAIL_PRODUCT` analysis (`DETAIL_TABLES="PRODUCT,CLAIM,LABOR"`) on the new Data Selection.
            create_verification_pareto (bool): When True and `folder_id` is provided, automatically creates and runs
                a `PARETO_PRODUCT` analysis on the new Data Selection.
            pareto_report_var (str): Report variable for the optional verification Pareto
                (default: 'CLAIM.PRIM_LABOR_CD').
        """
        import uuid

        logger.info("--- TOOL USED: synthesize_root_cause_data_selection_tool (%s) ---", new_name)
        async with viya_session("synthesize_root_cause_data_selection", ctx) as client:
            # 1. Copy parent Data Selection
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_data_selection_id}/copy"
            copy_payload: dict[str, Any] = {"name": new_name}
            if description:
                copy_payload["description"] = description
            if creation_type:
                copy_payload["creationType"] = creation_type
            resp_copy = await client.post(copy_url, json=copy_payload)
            resp_copy.raise_for_status()
            new_ds_id = resp_copy.json()["id"]

            # 2. Fetch full Data Selection & ETag
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                headers={"Accept": "application/vnd.sas.data.selection+json"},
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")

            if description:
                ds_details["description"] = description

            if start_date and end_date:
                ds_details["dateCriteria"] = {
                    "dateType": date_type,
                    "startDate": start_date,
                    "endDate": end_date,
                }

            filter_criteria = ds_details.get("filterCriteria", {})
            if "0" not in filter_criteria:
                filter_criteria["0"] = []
            group_0 = filter_criteria["0"]

            applied_filters: list[dict[str, Any]] = []
            for f_add in filters:
                comp = f_add.get("component") or f_add.get("componentTypeCode") or "PRODUCT"
                col_name = f_add["columnName"]
                op_code = f_add.get("operatorCode", "IN")
                vals = [str(v) for v in f_add.get("values", [])]
                match = next(
                    (
                        f for f in group_0
                        if f.get("columnName") == col_name
                        and (f.get("component") or f.get("componentTypeCode")) == comp
                    ),
                    None,
                )
                if match:
                    match["values"] = vals
                    match["operatorCode"] = op_code
                else:
                    group_0.append({
                        "id": str(uuid.uuid4()),
                        "criteriaGroupId": new_ds_id,
                        "columnName": col_name,
                        "operatorCode": op_code,
                        "excludeFlag": bool(f_add.get("excludeFlag", False)),
                        "componentTypeCode": comp,
                        "component": comp,
                        "filterAttributeId": f_add.get("filterAttributeId", f"{col_name}_{comp}"),
                        "groupId": "0",
                        "uiDisplay": False,
                        "values": vals,
                    })
                applied_filters.append({
                    "component": comp,
                    "columnName": col_name,
                    "operatorCode": op_code,
                    "values": vals,
                })

            ds_details["filterCriteria"] = filter_criteria
            if parent_analysis_id:
                attrs = list(ds_details.get("additionalAttributes") or [])
                attrs.append({"name": "parentAnalysisId", "value": parent_analysis_id})
                attrs.append({"name": "PARENT_ANALYSIS_ID", "value": parent_analysis_id})
                ds_details["additionalAttributes"] = attrs

            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}",
                json=ds_details,
                headers={
                    "Content-Type": "application/vnd.sas.data.selection+json",
                    "Accept": "application/vnd.sas.data.selection+json",
                    "If-Match": etag,
                },
            )
            resp_put.raise_for_status()
            data_selection_cache.clear()

            # 3. Launch consolidated Root-Cause Data Selection in CAS
            cols = [
                {"columnName": "PRODUCTION_DATE", "columnNameLabel": "Production Date",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnNameLabel": "Selling Dealer Country",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "MODEL_CD", "columnNameLabel": "Model Code",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_CD", "columnNameLabel": "Selling Dealer Code",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "INSERVICE_DATE", "columnNameLabel": "In Service Date",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "CSTMR_STATE_CD", "columnNameLabel": "Customer State",
                 "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code",
                 "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "CLAIMCOST", "columnNameLabel": "Total Claim Cost",
                 "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "PRIM_LABOR_CD", "columnNameLabel": "Primary Labor Code",
                 "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "EVENT_SUBMIT_DATE", "columnNameLabel": "Claim Submit Date",
                 "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "REPL_PART_CD", "columnNameLabel": "Replaced Part Code",
                 "columnTableName": "PART", "columnTableNameLabel": "Parts"},
            ]
            cas_table_name = f"DS_{new_ds_id.replace('-', '_')[:24]}"
            launch_body = {
                "tableName": cas_table_name,
                "launchAppName": "CAS",
                "transposeFlag": 0,
                "launchKeyDim": "PRODUCT",
                "launchColumnTables": ["CLAIM", "PART", "PRODUCT"],
                "launchColumns": cols,
            }
            resp_launch = await client.post(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches",
                json=launch_body,
                headers={
                    "Content-Type": "application/vnd.sas.data.selection.launch+json",
                    "Accept": "application/vnd.sas.data.selection.launch+json",
                },
            )
            resp_launch.raise_for_status()
            launch_id = resp_launch.json()["id"]

            poll_interval = 1.0
            deadline = time.monotonic() + 3600.0
            while True:
                resp_status = await client.get(
                    f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches/{launch_id}",
                    headers={"Accept": "application/vnd.sas.data.selection.launch+json"},
                )
                resp_status.raise_for_status()
                launch_status = (resp_status.json().get("status") or "").upper()
                if launch_status == "COMPLETED":
                    break
                if launch_status in ("FAILED", "ERROR", "CANCELED", "CANCELLED", "TIMEDOUT"):
                    raise RuntimeError(f"Data selection launch failed with status {launch_status}")
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"Data selection launch {launch_id} timed out")
                await asyncio.sleep(poll_interval)
                poll_interval = min(poll_interval * 1.5, 10.0)

            if folder_id:
                member_body = {
                    "name": new_name,
                    "uri": f"/dataSelection/dataSelections/{new_ds_id}",
                    "contentType": "application/vnd.sas.data.selection",
                    "type": "reference",
                }
                await client.post(
                    f"{VIYA_ENDPOINT}/folders/folders/{folder_id}/members",
                    json=member_body,
                    headers={
                        "Content-Type": "application/vnd.sas.drive.member+json",
                        "Accept": "application/vnd.sas.drive.member+json",
                    },
                )

        verification_analyses: list[dict[str, Any]] = []
        if folder_id and create_verification_detail_table:
            detail_res = await create_child_analysis_and_run_tool(
                name=f"{new_name}_Detail_Verification",
                model_name="DETAIL_PRODUCT",
                data_selection_id=new_ds_id,
                ctx=ctx,
                folder_id=folder_id,
                parameter_overrides={"DETAIL_TABLES": "PRODUCT,CLAIM,LABOR"},
            )
            verification_analyses.append({"type": "DETAIL_PRODUCT", **detail_res})

        if folder_id and create_verification_pareto:
            pareto_res = await create_child_analysis_and_run_tool(
                name=f"{new_name}_Pareto_Verification",
                model_name="PARETO_PRODUCT",
                data_selection_id=new_ds_id,
                ctx=ctx,
                folder_id=folder_id,
                parameter_overrides={"REPORT_VAR": pareto_report_var},
            )
            verification_analyses.append({"type": "PARETO_PRODUCT", **pareto_res})

        return {
            "status": "success",
            "data_selection_id": new_ds_id,
            "name": new_name,
            "cas_table_name": cas_table_name,
            "launch_id": launch_id,
            "date_criteria": (
                {"dateType": date_type, "startDate": start_date, "endDate": end_date}
                if (start_date and end_date)
                else None
            ),
            "applied_filters": applied_filters,
            "verification_analyses": verification_analyses,
            "message": (
                f"Successfully synthesized and launched single consolidated Root-Cause Data Selection "
                f"'{new_name}' (ID: {new_ds_id}) with {len(applied_filters)} orthogonal filter(s)."
            ),
        }


