import os
import re

filepath = r"C:\Git\sas-mcp-server\src\sas_mcp_server\tools\iot.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

tools_to_add = """

    @mcp.tool()
    async def get_iot_analysis_step_log_tool(analysis_id: str, step_id: str, ctx: Context) -> str:
        \"\"\"
        Retrieves the SAS Compute log for a specific step's latest job execution.
        Crucial for debugging CAF analyses that fail during execution.
        \"\"\"
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
                text = "...(truncated)...\\n" + text[-100000:]
            return text

    @mcp.tool()
    async def update_analysis_step_parameters_tool(analysis_id: str, step_id: str, parameters: dict, ctx: Context) -> dict:
        \"\"\"
        Updates specific input parameters for a single step of an Analysis. 
        Pass a dictionary of parameterName: parameterValue.
        \"\"\"
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
        \"\"\"
        Executes a specific step of an analysis and waits for its job to complete.
        \"\"\"
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
"""

if "get_iot_analysis_step_log_tool" not in content:
    # Append safely inside register function
    match = re.search(r"(\s+)(@mcp\.tool\(\)\s+async def \w+\(.*?\):.*?)(?=\Z|\s*#|$)", content, flags=re.DOTALL)
    if match:
        content = content.replace(match.group(2), tools_to_add + "\n" + match.group(1) + match.group(2))
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print("Tools added.")
    else:
        print("Regex failed")
