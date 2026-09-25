
import asyncio
async def main():
    import json, os
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    from sas_mcp_server.tools.iot import run_failure_relationships_analysis_tool
    class Ctx: pass
    import sas_mcp_server.tools.iot
    async def dummy_token(ctx): return token
    sas_mcp_server.tools.iot.get_token = dummy_token
    
    await run_failure_relationships_analysis_tool(
        name='Phase 3 - Broad Workmanship Sequence v2',
        data_selection_id='61631588-5dcf-48da-a12a-be58ab647f2a',
        folder_id='79eaaedd-2f6b-413f-8621-52b09325c818',
        ctx=Ctx(),
        analysis_var='LABOR.LABOR_AMOUNT',
        report_var='CLAIM.PRIM_LABOR_CD',
        data_domain='PRODUCT,CLAIM,LABOR',
        rv_dim_column='CLAIM.PRIM_LABOR_CD',
        rv_table_name_key='CLAIM.PRIM_LABOR_CD',
        rv_table_name_value='CLAIM.PRIM_LABOR_CD',
        rv_table_name='CLAIM.PRIM_LABOR_CD',
        wait_for_completion=False
    )
    print('Dispatched!')
asyncio.run(main())

