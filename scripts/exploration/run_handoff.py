import asyncio
import os
import json
import httpx
from unittest.mock import MagicMock
import sas_mcp_server.tools.compute
import sas_mcp_server.tools.iot

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        return json.load(f)['Default']['access-token']

sas_mcp_server.tools.compute.get_token = get_token
sas_mcp_server.tools.iot.get_token = get_token

async def main():
    mcp_mock = MagicMock()
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
    mcp_mock.tool.side_effect = mock_tool
    sas_mcp_server.tools.iot.register(mcp_mock, get_token)
    
    create_ds = tools['create_child_data_selection_and_launch_tool']
    run_exposure = tools['run_exposure_analysis_tool']
    run_reliability = tools['run_reliability_analysis_tool']

    class Ctx: pass
    ctx = Ctx()
    ctx.request_context = MagicMock()
    
    # Use Alert 9-040 Galacto
    parent_ds_id = '7d23ef73-9066-43b3-9196-03ab8ace3947'
    parent_analysis_id = 'ccaa5b1a-b112-482b-81a3-99c318d9080a'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    stat_var = "PRODUCT.CSTMR_STATE_CD"
    
    print("\nExecuting High-Cardinality Forecasting Hand-off...")
    
    # 1. Create Child Data Selection for Top States with NO extra filters to guarantee data exists
    new_filters = []
    
    print("Creating and launching child data selection...")
    res_ds = await create_ds(
        parent_data_selection_id=parent_ds_id,
        new_name=f"Phase 3 - Top States 0075",
        new_filters=new_filters,
        parent_analysis_id=parent_analysis_id,
        folder_id=folder_id,
        ctx=ctx
    )
    
    if not res_ds: return
    new_ds_id = res_ds['data_selection_id']
    print(f"Success! Created Child DS: {new_ds_id}")
    

    # Run Exposure and Reliability on PRODUCT,CLAIM!
    print("Dispatching Exposure...")
    await run_exposure(
        name=f"Phase 3 - Exposure 0075",
        data_selection_id=new_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.TOTAL_EVENT_AMT",
        data_domain="PRODUCT,CLAIM",
        by_var=stat_var,
        ctx=ctx,
        wait_for_completion=False
    )
    print("Dispatching Reliability...")
    await run_reliability(
        name=f"Phase 3 - Reliability 0075",
        data_selection_id=new_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.TOTAL_EVENT_AMT",
        report_var="CLAIM.PRIM_REPL_PART_CD",
        data_domain="PRODUCT,CLAIM",
        by_var=stat_var,
        ctx=ctx,
        wait_for_completion=False
    )
    print("Hand-off Complete!")
if __name__ == '__main__': asyncio.run(main())
