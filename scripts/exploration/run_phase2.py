import asyncio
import os
import json
import uuid
from unittest.mock import MagicMock
import sas_mcp_server.tools._common
import sas_mcp_server.tools.iot

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

sas_mcp_server.tools._common.get_token = get_token
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
    
    run_stat = tools['run_statistical_driver_analysis_tool']
    run_tree = tools['run_decision_tree_analysis_tool']
    
    uid = str(uuid.uuid4())[:4]
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    
    class Ctx: pass
    
    # We must only use columns that are physically loaded in the Data Selection launch.
    # The _BINNED columns are NOT in the launch profile for this specific data selection.
    phase2_report_vars = "PRODUCT.CSTMR_STATE_CD,PRODUCT.SELLING_DEALER_COUNTRY_CD,CLAIM.PRIM_LABOR_CD"
    
    await run_stat(
        name=f"Phase 2 - Stat Driver (Alarm 1) {uid}",
        data_selection_id=ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var=phase2_report_vars,
        wait_for_completion=False,
        ctx=Ctx()
    )
    
    await run_tree(
        name=f"Phase 2 - Decision Tree (Alarm 1) {uid}",
        data_selection_id=ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var=phase2_report_vars,
        wait_for_completion=False,
        ctx=Ctx()
    )

if __name__ == '__main__':
    asyncio.run(main())
