
import asyncio, json, os, time
from sas_mcp_server.tools.iot import run_pareto_analysis_tool, run_statistical_driver_analysis_tool, run_summary_tables_analysis_tool

class Ctx: pass
ctx = Ctx()

async def dummy_token(ctx):
    return json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']

import sas_mcp_server.tools.iot
sas_mcp_server.tools.iot.get_token = dummy_token

async def main():
    aid = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    
    print('Starting Phase 1...')
    res1 = await run_pareto_analysis_tool(
        name='Phase 1 - Pareto (Alert 2)',
        data_selection_id=aid,
        folder_id=folder_id,
        ctx=ctx,
        analysis_var='CLAIM.CLAIMCOST',
        report_var='PRODUCT.SELLING_DEALER_COUNTRY_CD'
    )
    print(res1)
    
    print('Starting Phase 2...')
    res2 = await run_statistical_driver_analysis_tool(
        name='Phase 2 - Statistical Drivers (Alert 2)',
        data_selection_id=aid,
        folder_id=folder_id,
        ctx=ctx,
        analysis_var='CLAIM.CLAIMCOST',
        report_var='PRODUCT.SELLING_DEALER_CD',
        target_var='CLAIM.CLAIMCOST'
    )
    print(res2)
    
    print('Starting Phase 3 (Summary Node for Documentation)...')
    res3 = await run_summary_tables_analysis_tool(
        name='Phase 3 - Sequence Findings (Alert 2)',
        data_selection_id=aid,
        folder_id=folder_id,
        ctx=ctx,
        analysis_var='CLAIM.CLAIMCOUNT',
        report_var='CLAIM.PRIM_REPL_PART_CD'
    )
    print(res3)
    
asyncio.run(main())

