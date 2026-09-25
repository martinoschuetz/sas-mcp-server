import asyncio
import os
import json
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

# Patch the get_token so tools don't fail
import sas_mcp_server.tools._common
sas_mcp_server.tools._common.get_token = get_token

async def main():
    ctx = DummyContext()
    mcp_mock = MagicMock()
    
    # Store tools
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
        
    mcp_mock.tool.side_effect = mock_tool
    
    # Register IoT tools
    register(mcp_mock, get_token)
    
    list_ds = tools['list_data_selections_tool']
    run_pareto = tools['run_pareto_analysis_tool']
    run_trend = tools['run_trend_analysis_tool']
    run_geo = tools['run_geographic_analysis_tool']
    run_summary = tools['run_summary_tables_analysis_tool']
    
    print("Fetching Data Selections...")
    res = await list_ds(limit=100, ctx=ctx)
    items = res.get('items', [])
    ds_id = None
    folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818" # MCP Test folder

    for ds in items:
        if ds.get('name') == "Alert 1 Galacto 9-040 DS":
            ds_id = ds.get('id')
            break
            
    if not ds_id:
        print("Could not find 'Alert 1 Galacto 9-040 DS'")
        return
        
    print(f"Found DS ID: {ds_id}")
    
    import uuid
    uid = str(uuid.uuid4())[:4]
    
    # 1. Pareto Analysis
    print("Launching Pareto Analysis...")
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

    # 2. Trend Analysis
    print("Launching Trend Analysis...")
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

    # 3. Geographic Analysis
    print("Launching Geographic Analysis...")
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
    
    # 4. Summary Tables
    print("Launching Summary Tables...")
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
