import asyncio
import os
import json
import uuid
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
    print("Launching Phase 1 Analyses with EXACT matching columns...")
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
    
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818"
    uid = str(uuid.uuid4())[:4]
    
    # 1. Pareto by CLAIM.PRIM_LABOR_CD
    await run_pareto(name=f"Phase 1 - Pareto Labor Code (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", by_var="CLAIM.PRIM_LABOR_CD", report_var="PRODUCT.MODEL_CD", wait_for_completion=False)
    
    # 2. Trend by CLAIM.EVENT_SUBMIT_DATE
    await run_trend(name=f"Phase 1 - Trend Analysis (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="CLAIM.EVENT_SUBMIT_DATE", wait_for_completion=False)
    
    # 3. Geo by PRODUCT.CSTMR_STATE_CD
    await run_geo(name=f"Phase 1 - Geographic Analysis (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="PRODUCT.CSTMR_STATE_CD", wait_for_completion=False)
    
    # 4. Summary Tables (Cross-tab: PRIM_REPL_PART_CD, MODEL_CD)
    await run_summary(name=f"Phase 1 - Summary Tables (Alarm 1) {uid}", data_selection_id=ds_id, ctx=ctx, folder_id=folder_id, analysis_var="CLAIM.CLAIMCOST", report_var="CLAIM.PRIM_REPL_PART_CD,PRODUCT.MODEL_CD", wait_for_completion=False)
    
    print("Launched!")

if __name__ == '__main__':
    asyncio.run(main())
