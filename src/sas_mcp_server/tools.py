# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Shared tool registration for both HTTP and stdio MCP servers.
All tools are registered via ``register_tools(mcp, get_token)``.
"""

from typing import Optional
from fastmcp import Context
from fastmcp.tools.tool import ToolResult
from .viya_utils import (
    _get_json,
    _get_paged_items,
    _post_json,
    _put_data,
    _delete_resource,
    _make_client,
    run_one_snippet,
    list_data_selections,
    get_data_selection,
    update_data_selection,
    delete_data_selection,
    launch_data_selection,
    copy_data_selection,
    copy_data_selections,
    list_iot_projects,
    list_iot_analyses,
    get_iot_analysis,
    create_iot_analysis,
    delete_iot_analysis,
    run_iot_analysis,
    copy_iot_analyses,
    get_iot_analysis_job,
    list_iot_models,
    get_iot_model,
    get_cas_summary_statistics,
    set_data_selection_date_range,
    run_iot_analysis_and_wait,
    launch_data_selection_and_wait,
    logger,
)


def register_tools(mcp, get_token):
    """Register all tools on *mcp*.

    Parameters
    ----------
    mcp : FastMCP
        The server instance to register tools on.
    get_token : callable
        ``async def get_token(ctx: Context) -> str`` — returns a Viya access
        token.  HTTP mode pulls it from context state; stdio mode acquires it
        via password grant.
    """

    # ------------------------------------------------------------------
    # Original tool
    # ------------------------------------------------------------------

    @mcp.tool()
    async def execute_sas_code(sas_code: str, ctx: Context) -> ToolResult:
        """
        Executes the provided SAS code in the Viya environment and returns information about the completed Job.
        This will create a job definition for the SAS code, execute it, and then retrieve the results.

        Args:
            sas_code (str): the SAS code snippet to be executed using the Viya Job Execution API Service

        Returns:
            Structured output data containing detailed information about the executed sas code.
            This includes a listing field and a log field. The listing output represents the intended output
            of the SAS code when executed, if the code ran successfully. The log output represents information
            about the execution of the sas code, such as if it ran successfully or not and whether or not there are
            errors or issues with the execution.

        """
        logger.info("--- TOOL USED: execute_sas_code ---")
        token = await get_token(ctx)
        output = await run_one_snippet(sas_code, "1", token)
        return output

    # ------------------------------------------------------------------
    # Tier 1 — Data Discovery (CAS Management)
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_cas_servers(ctx: Context) -> list:
        """List available CAS servers on the Viya environment."""
        logger.info("--- TOOL USED: list_cas_servers ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/casManagement/servers", client)
            return [{"name": s.get("name"), "id": s.get("id"),
                     "description": s.get("description", "")} for s in items]

    @mcp.tool()
    async def list_caslibs(server_id: str, ctx: Context,
                           limit: int = 50) -> list:
        """List CAS libraries (caslibs) available on a CAS server.

        Args:
            server_id: CAS server name or ID (e.g. 'cas-shared-default').
            limit: Maximum number of caslibs to return (default 50).
        """
        logger.info("--- TOOL USED: list_caslibs ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs", client, limit=limit)
            return [{"name": c.get("name"), "type": c.get("type", ""),
                     "description": c.get("description", "")} for c in items]

    @mcp.tool()
    async def list_castables(server_id: str, caslib_name: str, ctx: Context,
                             limit: int = 50) -> list:
        """List tables in a CAS library.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            limit: Maximum number of tables to return (default 50).
        """
        logger.info("--- TOOL USED: list_castables ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables",
                client, limit=limit)
            return [{"name": t.get("name"),
                     "rowCount": t.get("rowCount"),
                     "columnCount": t.get("columnCount")} for t in items]

    @mcp.tool()
    async def get_castable_info(server_id: str, caslib_name: str,
                                table_name: str, ctx: Context) -> dict:
        """Get metadata for a CAS table (row count, column count, size, etc.).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
        """
        logger.info("--- TOOL USED: get_castable_info ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _get_json(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}",
                client)

    @mcp.tool()
    async def get_castable_columns(server_id: str, caslib_name: str,
                                   table_name: str, ctx: Context,
                                   limit: int = 200) -> list:
        """Get column metadata for a CAS table (names, types, labels, formats).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
            limit: Maximum columns to return (default 200).
        """
        logger.info("--- TOOL USED: get_castable_columns ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}/columns",
                client, limit=limit)
            return [{"name": c.get("name"), "type": c.get("type"),
                     "rawLength": c.get("rawLength"),
                     "label": c.get("label", ""),
                     "format": c.get("format", "")} for c in items]

    @mcp.tool()
    async def get_castable_data(server_id: str, caslib_name: str,
                                table_name: str, ctx: Context,
                                limit: int = 20, start: int = 0) -> dict:
        """Fetch sample rows from a CAS table.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
            limit: Maximum rows to return (default 20).
            start: Row offset (default 0).
        """
        logger.info("--- TOOL USED: get_castable_data ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _get_json(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}/rows",
                client, params={"start": start, "limit": limit})

    @mcp.tool()
    async def get_castable_summary_statistics_tool(server_id: str, caslib_name: str,
                                              table_name: str, ctx: Context) -> dict:
        """Retrieves summary statistics for a CAS table (min, max, mean, count, etc.).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Name of the caslib.
            table_name: Name of the table.
        """
        logger.info(f"--- TOOL USED: get_castable_summary_statistics ({table_name}) ---")
        token = await get_token(ctx)
        return await get_cas_summary_statistics(server_id, caslib_name, table_name, token)

    # ------------------------------------------------------------------
    # Tier 2 — Data Operations & Files
    # ------------------------------------------------------------------

    @mcp.tool()
    async def upload_data(server_id: str, caslib_name: str, table_name: str,
                          csv_data: str, ctx: Context) -> dict:
        """Upload CSV data into a CAS table.

        Args:
            server_id: CAS server name or ID.
            caslib_name: Target caslib name.
            table_name: Name for the new table.
            csv_data: CSV-formatted data string (including header row).
        """
        logger.info("--- TOOL USED: upload_data ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _put_data(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}",
                client, data=csv_data.encode("utf-8"))

    @mcp.tool()
    async def promote_table_to_memory(server_id: str, caslib_name: str,
                                      table_name: str, ctx: Context) -> dict:
        """Promote a CAS table to global scope (makes it visible to all sessions).

        Args:
            server_id: CAS server name or ID.
            caslib_name: Caslib containing the table.
            table_name: Table to promote.
        """
        logger.info("--- TOOL USED: promote_table_to_memory ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _post_json(
                f"/casManagement/servers/{server_id}/caslibs/{caslib_name}/tables/{table_name}",
                client, params={"scope": "global"})

    @mcp.tool()
    async def list_files(ctx: Context, limit: int = 50,
                         filter_name: Optional[str] = None) -> list:
        """List files in the Viya Files Service.

        Args:
            limit: Maximum files to return (default 50).
            filter_name: Optional name filter (substring match).
        """
        logger.info("--- TOOL USED: list_files ---")
        token = await get_token(ctx)
        filters = f"contains(name,'{filter_name}')" if filter_name else None
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/files/files", client,
                                              limit=limit, filters=filters)
            return [{"id": f.get("id"), "name": f.get("name"),
                     "contentType": f.get("contentType", ""),
                     "size": f.get("size")} for f in items]

    @mcp.tool()
    async def upload_file(file_name: str, content: str, ctx: Context,
                          content_type: str = "text/plain") -> dict:
        """Upload a file to the Viya Files Service.

        Args:
            file_name: Name for the file.
            content: File content as a string.
            content_type: MIME type (default 'text/plain').
        """
        logger.info("--- TOOL USED: upload_file ---")
        token = await get_token(ctx)
        from .viya_utils import VIYA_ENDPOINT
        async with _make_client(token) as client:
            resp = await client.post(
                f"{VIYA_ENDPOINT}/files/files",
                content=content.encode("utf-8"),
                headers={"Content-Type": content_type,
                         "Content-Disposition": f'attachment; filename="{file_name}"',
                         "Accept": "application/json"})
            resp.raise_for_status()
            return resp.json()

    @mcp.tool()
    async def download_file(file_id: str, ctx: Context) -> str:
        """Download file content from the Viya Files Service.

        Args:
            file_id: ID of the file to download.
        """
        logger.info("--- TOOL USED: download_file ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            from .viya_utils import VIYA_ENDPOINT
            resp = await client.get(f"{VIYA_ENDPOINT}/files/files/{file_id}/content")
            resp.raise_for_status()
            return resp.text

    # ------------------------------------------------------------------
    # Tier 3 — Reports & Visualization
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_reports(ctx: Context, limit: int = 50,
                           filter_name: Optional[str] = None) -> list:
        """List Visual Analytics reports.

        Args:
            limit: Maximum reports to return (default 50).
            filter_name: Optional name filter (substring match).
        """
        logger.info("--- TOOL USED: list_reports ---")
        token = await get_token(ctx)
        filters = f"contains(name,'{filter_name}')" if filter_name else None
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/reports/reports", client,
                                              limit=limit, filters=filters)
            return [{"id": r.get("id"), "name": r.get("name"),
                     "description": r.get("description", ""),
                     "createdBy": r.get("createdBy", "")} for r in items]

    @mcp.tool()
    async def get_report(report_id: str, ctx: Context) -> dict:
        """Get a Visual Analytics report's metadata and definition.

        Args:
            report_id: ID of the report.
        """
        logger.info("--- TOOL USED: get_report ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _get_json(f"/reports/reports/{report_id}", client)

    @mcp.tool()
    async def get_report_image(report_id: str, ctx: Context,
                               image_type: str = "png",
                               section_index: int = 0) -> dict:
        """Render a Visual Analytics report section as an image.

        Args:
            report_id: ID of the report.
            image_type: Image format — 'png' or 'svg' (default 'png').
            section_index: Report section/page index (default 0).
        """
        logger.info("--- TOOL USED: get_report_image ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            body = {
                "reportUri": f"/reports/reports/{report_id}",
                "layoutType": "thumbnail",
                "selectionType": "perSection",
                "sectionIndex": section_index,
                "size": "800x600",
                "renderLimit": 1,
            }
            return await _post_json("/reportImages/jobs", client, body=body,
                                    accept=f"application/vnd.sas.report.images.job+json")

    # ------------------------------------------------------------------
    # Tier 4 — Batch Jobs & Async Execution
    # ------------------------------------------------------------------

    @mcp.tool()
    async def submit_batch_job(sas_code: str, ctx: Context,
                               job_name: Optional[str] = None) -> dict:
        """Submit a SAS job for asynchronous execution via the Job Execution service.

        Args:
            sas_code: SAS code to execute.
            job_name: Optional descriptive name for the job.
        """
        logger.info("--- TOOL USED: submit_batch_job ---")
        token = await get_token(ctx)
        body = {
            "name": job_name or "mcp-batch-job",
            "jobDefinition": {
                "type": "Compute",
                "code": sas_code,
            },
        }
        async with _make_client(token) as client:
            return await _post_json("/jobExecution/jobs", client, body=body)

    @mcp.tool()
    async def get_job_status(job_id: str, ctx: Context) -> dict:
        """Check the status of a submitted job.

        Args:
            job_id: ID of the job.
        """
        logger.info("--- TOOL USED: get_job_status ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _get_json(f"/jobExecution/jobs/{job_id}", client)

    @mcp.tool()
    async def list_jobs(ctx: Context, limit: int = 20) -> list:
        """List recent jobs from the Job Execution service.

        Args:
            limit: Maximum jobs to return (default 20).
        """
        logger.info("--- TOOL USED: list_jobs ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/jobExecution/jobs", client,
                                              limit=limit)
            return [{"id": j.get("id"), "name": j.get("name", ""),
                     "state": j.get("state", ""),
                     "creationTimeStamp": j.get("creationTimeStamp", "")} for j in items]

    @mcp.tool()
    async def cancel_job(job_id: str, ctx: Context) -> str:
        """Cancel a running job.

        Args:
            job_id: ID of the job to cancel.
        """
        logger.info("--- TOOL USED: cancel_job ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            await _delete_resource(f"/jobExecution/jobs/{job_id}", client)
            return f"Job {job_id} cancelled."

    @mcp.tool()
    async def get_job_log(job_id: str, ctx: Context) -> str:
        """Retrieve the log of a completed job.

        Args:
            job_id: ID of the job.
        """
        logger.info("--- TOOL USED: get_job_log ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            data = await _get_json(f"/jobExecution/jobs/{job_id}/log", client,
                                   accept="application/vnd.sas.collection+json")
            items = data.get("items", [])
            lines = [it.get("line", "") for it in items]
            return "\n".join(lines)

    # ------------------------------------------------------------------
    # Tier 5 — Model Management & Scoring
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_ml_projects(ctx: Context, limit: int = 50) -> list:
        """List AutoML pipeline automation projects.

        Args:
            limit: Maximum projects to return (default 50).
        """
        logger.info("--- TOOL USED: list_ml_projects ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items(
                "/mlPipelineAutomation/projects", client, limit=limit)
            return [{"id": p.get("id"), "name": p.get("name", ""),
                     "state": p.get("state", ""),
                     "description": p.get("description", "")} for p in items]

    @mcp.tool()
    async def create_ml_project(project_name: str, data_table_uri: str,
                                target_variable: str, ctx: Context,
                                description: str = "",
                                prediction_type: str = "classification") -> dict:
        """Create a new AutoML pipeline automation project.

        Args:
            project_name: Name for the project.
            data_table_uri: URI of the training data table (e.g. '/dataTables/dataSources/cas~fs~cas-shared-default~fs~Public/tables/HMEQ').
            target_variable: Name of the target/response variable.
            description: Optional project description.
            prediction_type: 'classification' or 'prediction' (default 'classification').
        """
        logger.info("--- TOOL USED: create_ml_project ---")
        token = await get_token(ctx)
        body = {
            "name": project_name,
            "description": description,
            "dataTableUri": data_table_uri,
            "targetVariable": target_variable,
            "analyticsProjectAttributes": {
                "predictionType": prediction_type,
            },
        }
        async with _make_client(token) as client:
            return await _post_json("/mlPipelineAutomation/projects", client, body=body)

    @mcp.tool()
    async def run_ml_project(project_id: str, ctx: Context) -> dict:
        """Run an AutoML pipeline automation project.

        Args:
            project_id: ID of the project to run.
        """
        logger.info("--- TOOL USED: run_ml_project ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            return await _post_json(
                f"/mlPipelineAutomation/projects/{project_id}", client,
                params={"action": "start"})

    @mcp.tool()
    async def list_registered_models(ctx: Context, limit: int = 50) -> list:
        """List models in the Model Repository.

        Args:
            limit: Maximum models to return (default 50).
        """
        logger.info("--- TOOL USED: list_registered_models ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/modelRepository/models", client,
                                              limit=limit)
            return [{"id": m.get("id"), "name": m.get("name", ""),
                     "description": m.get("description", ""),
                     "modelVersionName": m.get("modelVersionName", "")} for m in items]

    @mcp.tool()
    async def list_models_and_decisions(ctx: Context, limit: int = 50) -> list:
        """List published scoring models and decisions (MAS modules).

        Args:
            limit: Maximum modules to return (default 50).
        """
        logger.info("--- TOOL USED: list_models_and_decisions ---")
        token = await get_token(ctx)
        async with _make_client(token) as client:
            items, _ = await _get_paged_items("/microanalyticScore/modules", client,
                                              limit=limit)
            return [{"id": m.get("id"), "name": m.get("name", ""),
                     "description": m.get("description", "")} for m in items]

    @mcp.tool()
    async def score_data(module_id: str, step_id: str, input_data: dict,
                         ctx: Context) -> dict:
        """Score data against a published model or decision (MAS module).

        Args:
            module_id: MAS module ID.
            step_id: Step ID within the module (usually 'score' or 'execute').
            input_data: Dictionary of input variable name-value pairs.
        """
        logger.info("--- TOOL USED: score_data ---")
        token = await get_token(ctx)
        body = {"inputs": [{"name": k, "value": v} for k, v in input_data.items()]}
        async with _make_client(token) as client:
            return await _post_json(
                f"/microanalyticScore/modules/{module_id}/steps/{step_id}", client,
                body=body)

    # ------------------------------------------------------------------
    # Tier 6 — SAS Analytics for IoT (AIoT)
    # ------------------------------------------------------------------

    @mcp.tool()
    async def list_data_selections_tool(ctx: Context, filter_query: str = None, 
                                        start: int = 0, limit: int = 10) -> dict:
        """
        Lists all available SAS Analytics for IoT data selections.
        Returns a pruned list for improved performance.

        Args:
            filter_query (str): Optional filter string (e.g., "eq(createdBy,'Martin Schuetz')")
            start (int): Offset to start listing from (default: 0)
            limit (int): Maximum number of items to return (default: 10)
        """
        logger.info(f"--- TOOL USED: list_data_selections (filter: {filter_query}) ---")
        token = await get_token(ctx)
        raw_data = await list_data_selections(token, filter_query=filter_query, 
                                              start=start, limit=limit)
        
        # Prune response for speed
        items = raw_data.get("items", [])
        pruned_items = [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "createdBy": item.get("createdBy"),
                "creationTimeStamp": item.get("creationTimeStamp")
            }
            for item in items
        ]
        
        return {
            "count": raw_data.get("count"),
            "items": pruned_items,
            "limit": raw_data.get("limit"),
            "start": raw_data.get("start")
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
    async def create_iot_analysis_tool(name: str, model_name: str, data_selection_id: str, 
                                       ctx: Context, folder_id: str = None) -> dict:
        """
        Creates a new IoT analysis instance.

        Args:
            name (str): Name for the new analysis.
            model_name (str): Name of the analysis model (e.g., 'EXPLORATION_ASSET').
            data_selection_id (str): ID of the data selection to associate.
            folder_id (str): Optional ID of the project folder to create the analysis in.
        """
        logger.info(f"--- TOOL USED: create_iot_analysis ({name}) ---")
        token = await get_token(ctx)
        return await create_iot_analysis(name, model_name, data_selection_id, token, folder_id)

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
