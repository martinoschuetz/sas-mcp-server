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
    token = await get_token()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
    
    parent_ds_id = '21a65a93-8c37-4969-99b0-82ca2a260c2d'
    parent_launch_id = '70f0aab8-a5ba-47df-9e08-e839b01986cb'
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    
    async with httpx.AsyncClient(verify=False) as client:
        print("1. Fetching parent launch profile...")
        res = await client.get(f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{parent_ds_id}/launches/{parent_launch_id}", headers=headers)
        parent_launch = res.json()
        
        # Cleanup
        for k in ['id', 'links', 'jobId', 'status', 'displayStatus', 'creationTimeStamp', 'modifiedTimeStamp', 'createdBy', 'modifiedBy', 'owner', 'ownerDisplayName', 'tableURI', 'casServerName', 'casLibName']:
            parent_launch.pop(k, None)
        
        parent_launch['dataSelectionId'] = ds_id
        parent_launch['tableName'] = f"DS_{str(uuid.uuid4()).replace('-', '_')[:6]}"
        
        cols = parent_launch.get('launchColumns', [])
        for col in cols:
            col.pop('id', None)
            col.pop('dataSelectionLaunchId', None)
            
        existing_cols = {c['columnName'] for c in cols}
        
        needed_columns = [
            ("CLAIMCOST", "CLAIM"),
            ("EVENT_MONTH", "CLAIM"),
            ("STATE_PROVINCE_CD", "CLAIM"),
            ("REPL_PART_CD", "CLAIM"),
            ("MODEL_YR", "PRODUCT")
        ]
        
        for cname, ctable in needed_columns:
            if cname not in existing_cols:
                cols.append({
                    "columnName": cname,
                    "columnTableName": ctable,
                    "columnNameLabel": cname,
                    "columnTableNameLabel": ctable
                })
        
        parent_launch['launchColumns'] = cols
        
        print(f"\n2. Launching Target Data Selection with {len(cols)} columns as {parent_launch['tableName']}...")
        launch_url = f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{ds_id}/launches"
        launch_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection.launch+json', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}
        res_launch = await client.post(launch_url, headers=launch_headers, json=parent_launch)
        print("   Launch POST Status:", res_launch.status_code)
        
        if res_launch.status_code not in (200, 201):
            print("   Launch Error:", res_launch.text)
            return
            
        new_launch = res_launch.json()
        job_id = new_launch.get('jobId', new_launch.get('id'))
        
        job_url = f"https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{job_id}"
        while True:
            res_job = await client.get(job_url, headers=headers)
            state = res_job.json().get('state')
            if state in ['completed', 'failed']:
                if state == 'failed':
                    print("   LAUNCH FAILED:", res_job.json().get('error'))
                    return
                print("   Launch complete.")
                break
            await asyncio.sleep(3)
            
    # Now run the analyses!
    print("\n3. Launching Phase 1 Analyses...")
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
    
    run_pareto = tools['run_pareto_analysis_tool']
    run_trend = tools['run_trend_analysis_tool']
    run_geo = tools['run_geographic_analysis_tool']
    run_summary = tools['run_summary_tables_analysis_tool']
    
    folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818"
    uid = str(uuid.uuid4())[:4]
    
    pareto_res = await run_pareto(name=f"Phase 1 - Pareto Repl Part (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", by_var="CLAIM.REPL_PART_CD", report_var="PRODUCT.MODEL_CD", wait_for_completion=False)
    trend_res = await run_trend(name=f"Phase 1 - Trend Analysis (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="CLAIM.EVENT_MONTH", wait_for_completion=False)
    geo_res = await run_geo(name=f"Phase 1 - Geographic Analysis (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="CLAIM.STATE_PROVINCE_CD", wait_for_completion=False)
    sum_res = await run_summary(name=f"Phase 1 - Summary Tables (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="CLAIM.REPL_PART_CD,PRODUCT.MODEL_YR", wait_for_completion=False)
    
    print("Launched!")

if __name__ == '__main__':
    asyncio.run(main())
