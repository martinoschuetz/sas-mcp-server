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

    class Ctx: pass
    ctx = Ctx()
    ctx.request_context = MagicMock()
    
    # Use Alert 2
    parent_ds_id = "4092ac1f-43b4-49a9-b78c-9c003b09f4dd"  # Alert 2
    parent_analysis_id = "818c2846-9b4e-4a86-a9b6-4282dfdb538e"
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    
    print("\nExecuting Phase 1 & 2 for Alert 2...")
    
    # 1. Create Child Data Selection
    new_filters = []
    
    print("Creating and launching child data selection...")
    res_ds = await create_ds(
        parent_data_selection_id=parent_ds_id,
        new_name=f"Alert 2 Analysis DS",
        new_filters=new_filters,
        parent_analysis_id=parent_analysis_id,
        folder_id=folder_id,
        ctx=ctx
    )
    new_ds_id = res_ds.get('id')
    if not new_ds_id:
        print("Failed to create DS:", res_ds)
        return
    print(f"Success! Created Child DS: {new_ds_id}")
    
    from sas_mcp_server.tools.iot import run_pareto_analysis, run_statistical_driver_analysis
    
    print("Dispatching Pareto...")
    await run_pareto_analysis(
        name=f"Phase 1 - Pareto Alert 2",
        data_selection_id=new_ds_id,
        folder_id=folder_id,
        ctx=ctx,
        wait_for_completion=False
    )
    print("Dispatching Stat Driver...")
    await run_statistical_driver_analysis(
        name=f"Phase 2 - Stat Driver Alert 2",
        data_selection_id=new_ds_id,
        folder_id=folder_id,
        ctx=ctx,
        wait_for_completion=False
    )
    print("Hand-off Complete!")
if __name__ == '__main__': asyncio.run(main())
