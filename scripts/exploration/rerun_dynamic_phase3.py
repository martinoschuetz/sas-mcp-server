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
    sas_mcp_server.tools.compute.register(mcp_mock, get_token)
    sas_mcp_server.tools.iot.register(mcp_mock, get_token)
    
    run_failure = tools['run_failure_relationships_analysis_tool']
    run_exposure = tools['run_exposure_analysis_tool']
    run_reliability = tools['run_reliability_analysis_tool']
    delete_analysis = tools['delete_iot_analysis_tool']

    class Ctx: pass
    ctx = Ctx()
    ctx.request_context = MagicMock()
    
    token = await get_token()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers=headers)
        for a in res.json().get('items', []):
            if 'Phase 3' in a.get('name', '') or 'Failure Rel' in a.get('name', ''):
                print(f"Deleting outdated Analysis: {a.get('name')} (ID: {a.get('id')})")
                try:
                    await delete_analysis(analysis_id=a['id'], ctx=ctx)
                except Exception as e:
                    print(f"Failed to delete {a.get('name')}: {e}")
    
    child_ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    stat_var = "PRODUCT.CSTMR_STATE_CD"
    
    import uuid
    uid = str(uuid.uuid4())[:4]
    
    print("\nDispatching Dynamic Phase 3 (Workmanship/Labor routing)...")
    
    # 1. Failure Rel on LABOR because Phase 2 identified CSTMR_STATE_CD
    await run_failure(
        name=f"Phase 3 - Failure Rel (Workmanship) {uid}",
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var="CLAIM.PRIM_LABOR_CD",
        data_domain="PRODUCT,CLAIM,LABOR",
        rv_dim_column="CLAIM.PRIM_LABOR_CD",
        rv_table_name_key="CLAIM.PRIM_LABOR_CD",
        rv_table_name_value="CLAIM.PRIM_LABOR_CD",
        rv_table_name="CLAIM.PRIM_LABOR_CD",
        ctx=ctx,
        wait_for_completion=False
    )
    print("Dispatched Failure Relationships (Labor Domain).")
    
    # 2. Exposure Analysis
    await run_exposure(
        name=f"Phase 3 - Exposure {uid}",
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        by_var=stat_var,
        data_domain="PRODUCT,CLAIM,LABOR",
        ctx=ctx,
        wait_for_completion=False
    )
    print("Dispatched Exposure.")
    
    # 3. Reliability Analysis
    await run_reliability(
        name=f"Phase 3 - Reliability {uid}",
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="RELIABILITYCLAIMCOUNT",
        by_var=stat_var,
        report_var="CLAIM.PRIM_LABOR_CD",
        data_domain="PRODUCT,CLAIM,LABOR",
        ctx=ctx,
        wait_for_completion=False
    )
    print("Dispatched Reliability.")

if __name__ == '__main__':
    asyncio.run(main())
