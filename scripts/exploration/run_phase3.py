
from sas_mcp_server.tools.iot import run_failure_relationships_analysis
import asyncio

class Ctx:
    pass
ctx = Ctx()
async def get_token(ctx):
    import json, os
    return json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
import sas_mcp_server.tools.iot
sas_mcp_server.tools.iot.get_token = get_token

async def main():
    ds_id = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    
    print('Dispatching Workmanship Failure Rel...')
    await run_failure_relationships_analysis(
        name='Phase 3 - Failure Rel (Workmanship) Alert 2',
        data_selection_id=ds_id,
        folder_id=folder_id,
        ctx=ctx,
        analysis_var='CLAIM.CLAIMCOST',
        report_var='CLAIM.PRIM_LABOR_CD',
        data_domain='PRODUCT,CLAIM,LABOR',
        rv_dim_column='CLAIM.PRIM_LABOR_CD',
        wait_for_completion=False
    )
    print('Dispatching Hardware Failure Rel...')
    await run_failure_relationships_analysis(
        name='Phase 3 - Failure Rel (Hardware) Alert 2',
        data_selection_id=ds_id,
        folder_id=folder_id,
        ctx=ctx,
        analysis_var='CLAIM.CLAIMCOST',
        report_var='PART.REPL_PART_CD',
        data_domain='PRODUCT,CLAIM,PART',
        rv_dim_column='PART.REPL_PART_CD',
        wait_for_completion=False
    )
    print('Done!')
asyncio.run(main())

