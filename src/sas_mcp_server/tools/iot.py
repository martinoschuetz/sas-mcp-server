# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""SAS Analytics for IoT / FQA tools."""

import asyncio
import json
from collections.abc import Awaitable, Callable
from typing import Any

import httpx
from cachetools import TTLCache
from fastmcp import Context, FastMCP

from ..viya_client import logger, make_client
from ..viya_utils import run_one_snippet, get_context_id
from ._common import make_session_helpers

data_selection_cache = TTLCache(maxsize=100, ttl=60)
from ..config import VIYA_ENDPOINT


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
        
        return await _put_json(url, client, body=selection_data,
                               accept="application/vnd.sas.data.selection+json",
                               if_match=etag)


async def delete_data_selection(selection_id: str, token: str) -> None:
    """Deletes a SAS AIoT data selection."""
    async with make_client(token) as client:
        await _delete_resource(f"/dataSelection/dataSelections/{selection_id}", client)


async def launch_data_selection(selection_id: str, token: str) -> dict:
    """Triggers a launch job for a specific data selection."""
    async with make_client(token) as client:
        return await _post_json(f"/dataSelection/dataSelections/{selection_id}/launches", client,
                                body={},
                                accept="application/vnd.sas.data.selection.launch+json")


async def copy_data_selection(selection_id: str, new_name: str, token: str, new_description: str = "") -> dict:
    """Copies a specific SAS AIoT data selection."""
    async with make_client(token) as client:
        body = {"name": new_name, "description": new_description}
        return await _post_json(f"/dataSelection/dataSelections/{selection_id}/copy", client,
                                body=body,
                                accept="application/vnd.sas.data.selection+json")


async def copy_data_selections(selection_ids: list[str], token: str) -> dict:
    """Copies multiple SAS AIoT data selections."""
    async with make_client(token) as client:
        body = {"resources": selection_ids}
        return await _post_json("/dataSelection/dataSelectionActions/copies", client,
                                body=body,
                                accept="application/json")


async def list_iot_projects(token: str) -> dict:
    """Lists project instances from the IoT analysis service."""
    async with make_client(token) as client:
        return await _get_json("/iotAnalysis/projects", client,
                               accept="application/vnd.sas.collection+json")


async def list_iot_analyses(token: str, start: int = None, limit: int = None) -> dict:
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
    folder_id: str = None,
    parent_instance_id: str = None,
    parent_step_id: str = None,
    subset_group_name: str = None,
    filter_criteria: list = None
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

async def poll_job(job_url: str, token: str, poll_interval: int = 5) -> dict:
    """Polls a job status until it reaches a terminal state."""
    async with make_client(token) as client:
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


async def create_folder(name: str, token: str, parent_folder_id: str = "@myFolder", description: str = None) -> dict:
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


async def create_project(name: str, token: str, folder_id: str = "@myFolder", description: str = None) -> dict:
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
    async def list_data_selections_tool(
        ctx: Context,
        filter_query: str = None,
        start: int = 0,
        limit: int = 10,
        owner: str = None,
        owner_display_name: str = None,
        created_by: str = None,
        name: str = None,
        category: str = None,
        creation_type: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Lists all available SAS Analytics for IoT data selections.
        Supports filtering by any attribute (e.g., owner, owner_display_name) on the retrieved collection.

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
        """
        logger.info(f"--- TOOL USED: list_data_selections (filter: {filter_query}) ---")
        token = await get_token(ctx)

        # To support local filtering across the entire collection, fetch all items in batches
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

        return {
            "count": total_filtered_count,
            "items": pruned_items,
            "limit": limit,
            "start": start
        }

    @mcp.tool()
    async def get_data_selection_details(selection_id: str, ctx: Context) -> dict:
        """
        Retrieves detailed information and metadata for a specific SAS AIoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info(f"--- TOOL USED: get_data_selection_details ({selection_id}) ---")
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
        logger.info(f"--- TOOL USED: update_data_selection ({selection_id}) ---")
        token = await get_token(ctx)
        return await update_data_selection(selection_id, selection_data, token)

    @mcp.tool()
    async def delete_data_selection_tool(selection_id: str, ctx: Context) -> str:
        """
        Deletes a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection.
        """
        logger.info(f"--- TOOL USED: delete_data_selection ({selection_id}) ---")
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
        logger.info(f"--- TOOL USED: set_data_selection_date_range ({selection_id}) ---")
        token = await get_token(ctx)
        return await set_data_selection_date_range(selection_id, start_date, end_date, token)

    @mcp.tool()
    async def launch_data_selection_tool(selection_id: str, ctx: Context) -> dict:
        """
        Triggers a launch job for a specific data selection, loading the data into CAS for analysis.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
        """
        logger.info(f"--- TOOL USED: launch_data_selection ({selection_id}) ---")
        token = await get_token(ctx)
        return await launch_data_selection(selection_id, token)

    @mcp.tool()
    async def launch_data_selection_and_wait_tool(selection_id: str, ctx: Context) -> dict:
        """
        Launches a data selection and waits for the job to complete.

        Args:
            selection_id (str): The unique identifier of the data selection to launch.
        """
        logger.info(f"--- TOOL USED: launch_data_selection_and_wait ({selection_id}) ---")
        token = await get_token(ctx)
        return await launch_data_selection_and_wait(selection_id, token)

    @mcp.tool()
    async def copy_data_selection_tool(selection_id: str, new_name: str, 
                                       ctx: Context, new_description: str = "") -> dict:
        """
        Copies a specific SAS Analytics for IoT data selection.

        Args:
            selection_id (str): The unique identifier of the data selection to copy.
            new_name (str): The name for the new data selection.
            new_description (str): Optional description for the new data selection.
        """
        logger.info(f"--- TOOL USED: copy_data_selection ({selection_id} -> {new_name}) ---")
        token = await get_token(ctx)
        return await copy_data_selection(selection_id, new_name, token, new_description)

    @mcp.tool()
    async def copy_data_selections_tool(selection_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT data selections.

        Args:
            selection_ids (list[str]): List of data selection identifiers to copy.
        """
        logger.info(f"--- TOOL USED: copy_data_selections ({len(selection_ids)} items) ---")
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
        logger.info(f"--- TOOL USED: get_iot_analysis_details ({analysis_id}) ---")
        token = await get_token(ctx)
        return await get_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def create_iot_analysis_tool(
        name: str,
        model_name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_instance_id: str = None,
        parent_step_id: str = None,
        subset_group_name: str = None,
        filter_criteria: list = None
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
        logger.info(f"--- TOOL USED: create_iot_analysis ({name}) ---")
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
        logger.info(f"--- TOOL USED: delete_iot_analysis ({analysis_id}) ---")
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
        logger.info(f"--- TOOL USED: run_iot_analysis ({analysis_id}) ---")
        token = await get_token(ctx)
        return await run_iot_analysis(analysis_id, token)

    @mcp.tool()
    async def run_iot_analysis_and_wait_tool(analysis_id: str, ctx: Context) -> dict:
        """
        Runs a specific IoT analysis and waits for the job to complete.

        Args:
            analysis_id (str): The unique identifier of the analysis to run.
        """
        logger.info(f"--- TOOL USED: run_iot_analysis_and_wait ({analysis_id}) ---")
        token = await get_token(ctx)
        return await run_iot_analysis_and_wait(analysis_id, token)

    @mcp.tool()
    async def copy_iot_analyses_tool(analysis_ids: list[str], ctx: Context) -> dict:
        """
        Copies multiple SAS Analytics for IoT analyses.

        Args:
            analysis_ids (list[str]): List of analysis identifiers to copy.
        """
        logger.info(f"--- TOOL USED: copy_iot_analyses ({len(analysis_ids)} items) ---")
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
        logger.info(f"--- TOOL USED: get_iot_analysis_results ({analysis_id}, {job_id}) ---")
        token = await get_token(ctx)
        return await get_iot_analysis_job(analysis_id, job_id, token)

    @mcp.tool()
    async def get_iot_analysis_output_tables_tool(analysis_id: str, ctx: Context) -> list[str]:
        """
        Finds the names of CAS tables generated by an IoT analysis.

        Args:
            analysis_id (str): The unique identifier of the analysis.
        """
        logger.info(f"--- TOOL USED: get_iot_analysis_output_tables ({analysis_id}) ---")
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
        logger.info(f"--- TOOL USED: get_iot_model_definition ({model_name}) ---")
        token = await get_token(ctx)
        return await get_iot_model(model_name, token)

    @mcp.tool()
    async def list_emerging_issue_runs_tool(
        ctx: Context,
        start: int = 0,
        limit: int = 10,
        name: str = None,
        status: str = None,
        created_by: str = None,
        owner: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Lists all Emerging Issue analysis runs.
        Supports filtering by any attribute (e.g., name, status, owner, createdBy) on the retrieved collection.

        Args:
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
            name (str): Optional case-insensitive substring filter for run name (e.g., 'Emerging')
            status (str): Optional case-insensitive substring filter for run status (e.g., 'Completed')
            created_by (str): Optional case-insensitive substring filter for creator name (e.g., 'germsz')
            owner (str): Optional case-insensitive substring filter for owner username or display name
            attribute_filters (dict): Optional dictionary mapping any attribute name to target value
                                      for dynamic filtering
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

        total_filtered_count = len(filtered_items)
        paginated_items = filtered_items[start : start + limit]

        pruned_items = [
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
            for item in paginated_items
        ]

        return {
            "items": pruned_items,
            "total": total_filtered_count,
            "start": start,
            "limit": limit
        }

    @mcp.tool()
    async def list_alerts_for_run_tool(
        analysis_id: str,
        ctx: Context,
        start: int = 0,
        limit: int = 20,
        alert_id: str = None,
        alert_type: str = None,
        model_cd: str = None,
        cstmr_country_cd: str = None,
        seasonal_flag: str = None,
        display_status_cd: str = None,
        attribute_filters: dict = None
    ) -> dict:
        """
        Retrieves the list of alerts generated by a completed Emerging Issue analysis run.
        Supports case-insensitive filtering on any alert attribute.

        Args:
            analysis_id (str): The unique ID of the Emerging Issue analysis/run.
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 20)
            alert_id (str): Optional case-insensitive filter for alert ID
            alert_type (str): Optional case-insensitive filter for alert type (e.g., 'PRODUCTIONPERIOD')
            model_cd (str): Optional case-insensitive filter for model code (e.g., 'Beta', 'Abyss')
            cstmr_country_cd (str): Optional case-insensitive filter for customer country code (e.g., '840')
            seasonal_flag (str): Optional case-insensitive filter for seasonal flag (e.g., 'N', 'Y')
            display_status_cd (str): Optional case-insensitive filter for display status code (e.g., 'Active')
            attribute_filters (dict): Optional dictionary of additional attribute-value filters
        """
        logger.info(f"--- TOOL USED: list_alerts_for_run ({analysis_id}) ---")
        token = await get_token(ctx)

        # 1. Retrieve the analysis definition to check its shortId
        analysis = await get_iot_analysis(analysis_id, token)
        short_id = analysis.get("shortId")
        if not short_id:
            short_id = analysis_id.split("-")[0]

        model_name = analysis.get("modelName", "EIENTERPRISE_PRODUCT")
        prefix = model_name.split("_")[0] if "_" in model_name else model_name

        # 2. Query CAS server to find the exact alerts table name
        cas_code = """
        cas mySession;
        caslib _all_ assign;
        proc cas;
          table.tableInfo / caslib="QASANLOUT";
        quit;
        """
        
        res = await run_one_snippet(cas_code, "find_alerts_table", token)
        listing = res.get("listing", "")
        
        import re
        table_pattern = rf"([A-Za-z0-9_]+_ALERTS_{short_id})"
        matches = re.findall(table_pattern, listing, re.IGNORECASE)
        
        if matches:
            matched_table = matches[0].upper()
            logger.info(f"Dynamically discovered alerts table name: {matched_table}")
        else:
            matched_table = f"{prefix}_ALERTS_{short_id}".upper()
            logger.warning(
                "Could not discover alerts table name via tableInfo. "
                f"Falling back to default: {matched_table}"
            )

        # 3. Export discovered table to JSON using SAS PROC JSON in a compute session
        export_code = f"""
        cas mySession;
        caslib _all_ assign;
        libname mycas cas caslib="QASANLOUT" sessref=mySession;

        filename myjson temp;
        proc json out=myjson pretty;
          export mycas.{matched_table};
        run;

        data _null_;
          infile myjson;
          input;
          put "JSON_OUT: " _infile_;
        run;
        """
        
        export_res = await run_one_snippet(export_code, "export_alerts", token)
        export_log = export_res.get("log", "")
        
        # 4. Extract and parse JSON data
        json_lines = []
        for line in export_log.splitlines():
            if line.startswith("JSON_OUT: "):
                json_lines.append(line[len("JSON_OUT: "):])
        
        json_str = "\n".join(json_lines)
        if not json_str.strip():
            logger.error(f"No JSON output from PROC JSON. Check log: {export_log}")
            return {
                "items": [],
                "total": 0,
                "start": start,
                "limit": limit,
                "message": (
                    f"No alerts found for run '{analysis_id}'. It might not "
                    f"have generated any alerts or table '{matched_table}' is empty."
                )
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
                "start": start,
                "limit": limit,
                "error": f"Failed to parse alerts data from SAS log: {str(e)}"
            }

        # 5. Apply filtering on retrieved alerts
        def matches_filter(item_val, filter_val) -> bool:
            if item_val is None:
                return False
            return str(filter_val).lower() in str(item_val).lower()

        filtered_alerts = alerts

        if alert_id:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("alert_id"), alert_id)]
        if alert_type:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("alert_type"), alert_type)]
        if model_cd:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("model_cd"), model_cd)]
        if cstmr_country_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(a.get("cstmr_country_cd"), cstmr_country_cd)
            ]
        if seasonal_flag:
            filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get("seasonal_flag"), seasonal_flag)]
        if display_status_cd:
            filtered_alerts = [
                a for a in filtered_alerts
                if matches_filter(a.get("display_status_cd"), display_status_cd)
            ]

        if attribute_filters:
            for attr, val in attribute_filters.items():
                filtered_alerts = [a for a in filtered_alerts if matches_filter(a.get(attr), val)]

        total_count = len(filtered_alerts)
        paginated_alerts = filtered_alerts[start : start + limit]

        return {
            "items": paginated_alerts,
            "total": total_count,
            "start": start,
            "limit": limit
        }

    @mcp.tool()
    async def list_folders_and_projects_tool(folder_id: str = None, ctx: Context = None) -> dict:
        """
        Lists folders, projects, and other members within a parent folder.
        If no folder_id is specified, lists root level folders and the user's home folder.

        Args:
            folder_id (str): Optional parent folder ID or URI.
        """
        logger.info(f"--- TOOL USED: list_folders_and_projects (folder_id={folder_id}) ---")
        token = await get_token(ctx)
        return await list_folders_and_projects(token, folder_id)

    @mcp.tool()
    async def create_folder_tool(
        name: str,
        parent_folder_id: str = "@myFolder",
        description: str = None,
        ctx: Context = None
    ) -> dict:
        """
        Creates a new folder inside a parent folder.

        Args:
            name (str): Name of the new folder.
            parent_folder_id (str): Parent folder ID or shortcut (defaults to '@myFolder').
            description (str): Optional folder description.
        """
        logger.info(f"--- TOOL USED: create_folder (name={name}, parent={parent_folder_id}) ---")
        token = await get_token(ctx)
        return await create_folder(name, token, parent_folder_id, description)

    @mcp.tool()
    async def create_project_tool(
        name: str,
        folder_id: str = "@myFolder",
        description: str = None,
        ctx: Context = None
    ) -> dict:
        """
        Creates a new IoT project under a folder.

        Args:
            name (str): Name of the project.
            folder_id (str): Folder ID to place the project in (defaults to '@myFolder').
            description (str): Optional project description.
        """
        logger.info(f"--- TOOL USED: create_project (name={name}, folder={folder_id}) ---")
        token = await get_token(ctx)
        return await create_project(name, token, folder_id, description)

    @mcp.tool()
    async def delete_folder_tool(folder_id: str, ctx: Context = None) -> str:
        """
        Deletes an existing folder by its ID or URI.

        Args:
            folder_id (str): The ID of the folder to delete.
        """
        logger.info(f"--- TOOL USED: delete_folder (folder_id={folder_id}) ---")
        token = await get_token(ctx)
        await delete_folder(folder_id, token)
        return f"Folder {folder_id} deleted successfully."

    @mcp.tool()
    async def delete_project_tool(project_id: str, ctx: Context = None) -> str:
        """
        Deletes an existing IoT project by its ID.

        Args:
            project_id (str): The ID of the project to delete.
        """
        logger.info(f"--- TOOL USED: delete_project (project_id={project_id}) ---")
        token = await get_token(ctx)
        await delete_project(project_id, token)
        return f"Project {project_id} deleted successfully."

    @mcp.tool()
    async def run_pareto_analysis_tool(
        name: str,
        data_selection_id: str,
        ctx: Context,
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_pareto_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_trend_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_trend_by_exposure_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_detail_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_statistical_driver_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_decision_tree_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_event_forecasting_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_summary_tables_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_text_mining_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_exposure_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_failure_relationships_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_geographic_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_time_of_event_analysis ({name}) ---")
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
        folder_id: str = None,
        parent_analysis_id: str = None,
        parent_analysis_owner: str = None,
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
        logger.info(f"--- TOOL USED: run_reliability_analysis ({name}) ---")
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
        logger.info(f"--- TOOL USED: drop_table_from_memory ({caslib_name}.{table_name}) ---")
        token = await get_token(ctx)
        code = f"""
        cas mySession;
        proc cas;
          table.dropTable / caslib="{caslib_name}" name="{table_name}" quiet=true;
        quit;
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
        logger.info(f"--- TOOL USED: reload_table_to_memory ({caslib_name}.{table_name}) ---")
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
            fqa_base_path (str): The absolute Linux path on the CAS server where the FQA Demo_Data_transformed directory resides 
                                 (e.g., "/export/sas-viya/homes/germsz/AIoT/FQA/Demo_Data_transformed").
        """
        logger.info(f"--- TOOL USED: reload_fqa_metadata_tool ({fqa_base_path}) ---")
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
        - 'binning': Groups the top 10 values by frequency and bins the rest as -99 ('OTHER').
        - 'temporal': Extracts Year-Month and relative age offsets (requires target_column representing inservice_date).
        - 'target_encoding': Calculates target encoding using the mean of target_column.

        Args:
            caslib_name: Name of the caslib containing the table.
            table_name: Name of the CAS table.
            column_name: Name of the high-cardinality column to remediate.
            strategy: Remediation strategy ('binning', 'temporal', or 'target_encoding').
            target_column: Name of the target variable for target encoding or target inservice_date for temporal.
        """
        logger.info(f"--- TOOL USED: remediate_high_cardinality ({caslib_name}.{table_name}.{column_name}) ---")
        token = await get_token(ctx)
        
        column_name = column_name.upper()
        table_name = table_name.upper()
        caslib_name = caslib_name.upper()
        if target_column:
            target_column = target_column.upper()
            
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
        new_type = 3
        
        if strategy == "binning":
            new_col = f"{column_name}_BINNED"
            new_desc = f"Binned {column_name} (Top 10 + Other)"
            new_label = f"Binned {column_name}"
            new_type = 3
            
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
                       case when t2.{column_name} is not null then t1.{column_name}
                            else -99
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
                "log": res.get("log")[:1000]
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
    ) -> dict[str, Any]:
        """Creates a child data selection from a parent data selection with new filters and parent links, and launches it in CAS.

        Args:
            parent_data_selection_id (str): The ID of the parent data selection to copy.
            new_name (str): Name for the new child data selection.
            new_filters (list[dict]): List of additional filter criteria to append.
            parent_analysis_id (str): The ID of the parent Decision Tree or analysis to link this child to.
            folder_id (str, optional): The ID of the project folder to add this data selection to.
        """
        import uuid
        async with viya_session("create_child_data_selection_and_launch", ctx) as client:
            logger.info(f"Copying parent data selection {parent_data_selection_id} to '{new_name}'")
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_data_selection_id}/copies?name={new_name}"
            resp_copy = await client.post(copy_url)
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
                    "filterAttributeId": f.get("filterAttributeId", f"{f.get('columnName')}_{f.get('component', 'PRODUCT')}"),
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
            
            cols = [
                {"columnName": "PRODUCTION_DATE", "columnNameLabel": "Production Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnNameLabel": "Selling Dealer Country", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "MODEL_CD", "columnNameLabel": "Model Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_CD", "columnNameLabel": "Selling Dealer Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "INSERVICE_DATE", "columnNameLabel": "In Service Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "CSTMR_STATE_CD", "columnNameLabel": "Customer State", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "CLAIMCOST", "columnNameLabel": "Total Claim Cost", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "PRIM_LABOR_CD", "columnNameLabel": "Primary Labor Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "EVENT_SUBMIT_DATE", "columnNameLabel": "Claim Submit Date", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "REPL_PART_CD", "columnNameLabel": "Replaced Part Code", "columnTableName": "PART", "columnTableNameLabel": "Parts"}
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
            
            import asyncio
            while True:
                resp_status = await client.get(
                    f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches/{launch_id}",
                    headers={"Accept": "application/vnd.sas.data.selection.launch+json"}
                )
                launch_status = resp_status.json().get("status", "")
                if launch_status == "COMPLETED":
                    break
                elif launch_status in ("FAILED", "ERROR"):
                    raise RuntimeError(f"Data selection launch failed with status {launch_status}")
                await asyncio.sleep(5)
                
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
        """Creates a child analysis instance, configures step parameters with overrides, runs the job, and links it in a project folder.

        Args:
            name (str): The name for the new analysis instance.
            model_name (str): The type of analysis model (e.g. `DETAIL_PRODUCT`, `PARETO_PRODUCT`).
            data_selection_id (str): The ID of the data selection to run the analysis on.
            folder_id (str, optional): The ID of the project folder to add this analysis to.
            parameter_overrides (dict, optional): Parameter overrides to update in the analysis step.
        """
        async with viya_session("create_child_analysis_and_run", ctx) as client:
            logger.info(f"Creating new analysis '{name}' on data selection {data_selection_id}")
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
                headers={"Accept": "application/json"}
            )
            resp_run.raise_for_status()
            job_link = resp_run.json()["links"][0]["href"]
            
            import asyncio
            while True:
                resp_job = await client.get(f"{VIYA_ENDPOINT}{job_link}")
                job_status = resp_job.json().get("state", "")
                if job_status == "completed":
                    break
                elif job_status in ("failed", "error", "canceled"):
                    try:
                        log_resp = await client.get(f"{VIYA_ENDPOINT}{job_link}/log?limit=1000")
                        log_lines = [item.get("line") for item in log_resp.json().get("items", [])]
                        logger.error("Job log output:\n" + "\n".join(log_lines))
                    except Exception:
                        pass
                    raise RuntimeError(f"Analysis job failed with status {job_status}")
                await asyncio.sleep(5)
                
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
    async def list_forecasting_data_definitions(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:
        """List Visual Forecasting data definitions."""
        async with viya_session("list_forecasting_data_definitions", ctx) as client:
            return await _get_paged_items(client, "/dataDefinitions", limit, start)

    @mcp.tool()
    async def get_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> dict:
        """Get details of a specific Visual Forecasting data definition."""
        async with viya_session("get_forecasting_data_definition", ctx) as client:
            return await _get_json(client, f"/dataDefinitions/{data_definition_id}")

    @mcp.tool()
    async def create_forecasting_data_definition(body: str, ctx: Context = None) -> dict:
        """Create a new Visual Forecasting data definition (pass configuration as a JSON string)."""
        async with viya_session("create_forecasting_data_definition", ctx) as client:
            return await _post_json(client, "/dataDefinitions", json.loads(body))

    @mcp.tool()
    async def delete_forecasting_data_definition(data_definition_id: str, ctx: Context = None) -> str:
        """Delete a Visual Forecasting data definition."""
        async with viya_session("delete_forecasting_data_definition", ctx) as client:
            await _delete_resource(client, f"/dataDefinitions/{data_definition_id}")
            return f"Deleted data definition {data_definition_id}"

    @mcp.tool()
    async def run_final_forecast(data_definition_id: str, ctx: Context = None) -> dict:
        """Run the final forecast for a data definition."""
        async with viya_session("run_final_forecast", ctx) as client:
            return await _post_json(client, f"/dataDefinitions/{data_definition_id}/finalForecast", {})

    @mcp.tool()
    async def list_forecasting_filters(limit: int = 10, start: int = 0, ctx: Context = None) -> dict:
        """List Visual Forecasting filters."""
        async with viya_session("list_forecasting_filters", ctx) as client:
            return await _get_paged_items(client, "/filters", limit, start)

    @mcp.tool()
    async def get_forecasting_filter(filter_id: str, ctx: Context = None) -> dict:
        """Get details of a specific Visual Forecasting filter."""
        async with viya_session("get_forecasting_filter", ctx) as client:
            return await _get_json(client, f"/filters/{filter_id}")


    @mcp.tool()
    async def get_forecasting_pipeline_results(pipeline_id: str, component_id: str, ctx: Context = None) -> dict:
        """Get the results of a specific component within a forecasting pipeline."""
        async with viya_session("get_forecasting_pipeline_results", ctx) as client:
            return await _get_json(client, f"/pipelines/{pipeline_id}/components/{component_id}/results")

    @mcp.tool()
    async def run_forecasting_comparison(body: str, ctx: Context = None) -> dict:
        """Run a forecasting pipeline comparison (pass configuration as a JSON string)."""
        async with viya_session("run_forecasting_comparison", ctx) as client:
            return await _post_json(client, "/comparison", json.loads(body))

    @mcp.tool()
    async def get_forecasting_comparison_results(ctx: Context = None) -> dict:
        """Get forecasting comparison results."""
        async with viya_session("get_forecasting_comparison_results", ctx) as client:
            return await _get_json(client, "/comparison/results")

    @mcp.tool()
    async def generate_forecasting_timeseries_plot(body: str, ctx: Context = None) -> dict:
        """Generate a time series plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecasting_timeseries_plot", ctx) as client:
            return await _post_json(client, "/timeSeriesPlot", json.loads(body))

    @mcp.tool()
    async def generate_forecast_plot(body: str, ctx: Context = None) -> dict:
        """Generate a forecast plot for exploration (pass configuration as a JSON string)."""
        async with viya_session("generate_forecast_plot", ctx) as client:
            return await _post_json(client, "/forecastPlot", json.loads(body))

