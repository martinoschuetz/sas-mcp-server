import asyncio
import os
import json
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
    sas_mcp_server.tools.compute.register(mcp_mock, get_token)
    sas_mcp_server.tools.iot.register(mcp_mock, get_token)
    
    run_failure = tools['run_failure_relationships_analysis_tool']
    
    class Ctx: pass
    ctx = Ctx()
    ctx.request_context = MagicMock()
    
    # We use the correct DS ID and Folder ID from before
    child_ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    
    import uuid
    uid = str(uuid.uuid4())[:4]
    
    print("Re-dispatching Failure Relationships Analysis with correct parameters...")
    # Because we are using LABOR, we must set data_domain="PRODUCT,CLAIM,LABOR"
    # and rv_dim_column must match the report_var!
    
    res = await run_failure(
        name=f"Phase 3 - Failure Rel FIXED {uid}",
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var="CLAIM.PRIM_LABOR_CD",
        data_domain="PRODUCT,CLAIM,LABOR",
        rv_dim_column="CLAIM.PRIM_LABOR_CD",
        ctx=ctx,
        wait_for_completion=False
    )
    print("Successfully dispatched FIXED Failure Relationships Analysis!")

if __name__ == '__main__':
    asyncio.run(main())
