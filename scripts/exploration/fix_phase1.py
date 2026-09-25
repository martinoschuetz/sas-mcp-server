import asyncio
import os
import json
import uuid
import httpx
from unittest.mock import MagicMock
from sas_mcp_server.tools.iot import register

class DummyContext:
    def __init__(self):
        self.request_context = MagicMock()

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

import sas_mcp_server.tools._common
sas_mcp_server.tools._common.get_token = get_token
sas_mcp_server.tools.iot.get_token = get_token

async def main():
    ctx = DummyContext()
    mcp_mock = MagicMock()
    
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
    mcp_mock.tool.side_effect = mock_tool
    register(mcp_mock, get_token)
    
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    token = await get_token()
    
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection.launch+json', 'Content-Type': 'application/json'}
    url = f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{ds_id}/launches'
    
    print("1. Launching Data Selection...")
    async with httpx.AsyncClient(verify=False) as client:
        # Proper FQA launch payload
        launch_body = {
            "tableName": f"DS_{ds_id.replace('-', '_')[:24]}",
            "launchAppName": "CAS",
            "transposeFlag": 0,
            "launchKeyDim": "PRODUCT",
            "launchColumnTables": ["CLAIM", "PRODUCT", "LABOR"]
        }
        res = await client.post(url, headers=headers, json=launch_body)
        print("Launch Creation:", res.status_code, res.text[:200])
        
        if res.status_code in [200, 201]:
            job_url = f"https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{res.json()['id']}"
            while True:
                res_job = await client.get(job_url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
                state = res_job.json().get('state')
                print("Launch state:", state)
                if state in ['completed', 'failed']:
                    break
                await asyncio.sleep(2)
                
    run_pareto = tools['run_pareto_analysis_tool']
    run_trend = tools['run_trend_analysis_tool']
    run_geo = tools['run_geographic_analysis_tool']
    run_summary = tools['run_summary_tables_analysis_tool']
    
    folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818"
    uid = str(uuid.uuid4())[:4]
    
    print("\n2. Launching Phase 1 Analyses...")
    pareto_res = await run_pareto(
        name=f"Phase 1 - Pareto Labor Code (Alarm 1) {uid}",
        data_selection_id=ds_id,
        ctx=ctx,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        by_var="CLAIM.LABOR_CODE",
        report_var="PRODUCT.MODEL_CD",
        wait_for_completion=False
    )
    print("Pareto:", pareto_res)

    trend_res = await run_trend(
        name=f"Phase 1 - Trend Analysis by Event Month (Alarm 1) {uid}",
        data_selection_id=ds_id,
        ctx=ctx,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var="CLAIM.EVENT_MONTH",
        wait_for_completion=False
    )
    print("Trend:", trend_res)

    geo_res = await run_geo(
        name=f"Phase 1 - Geographic Analysis (Alarm 1) {uid}",
        data_selection_id=ds_id,
        ctx=ctx,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var="CLAIM.STATE_PROVINCE_CD",
        wait_for_completion=False
    )
    print("Geographic:", geo_res)
    
    sum_res = await run_summary(
        name=f"Phase 1 - Summary Tables (Alarm 1) {uid}",
        data_selection_id=ds_id,
        ctx=ctx,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var="CLAIM.REPL_PART_CD,PRODUCT.MODEL_YR",
        wait_for_completion=False
    )
    print("Summary Tables:", sum_res)

if __name__ == '__main__':
    asyncio.run(main())
