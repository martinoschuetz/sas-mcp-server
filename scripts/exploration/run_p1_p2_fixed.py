
from sas_mcp_server.tools.iot import run_pareto_analysis, run_statistical_driver_analysis
import asyncio

class Ctx: pass
ctx = Ctx()
async def get_token(ctx):
    import json, os
    return json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
import sas_mcp_server.tools.iot
sas_mcp_server.tools.iot.get_token = get_token

async def main():
    ds_id = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    report_var = 'PRODUCT.SELLING_DEALER_COUNTRY_CD,PRODUCT.CSTMR_STATE_CD,PRODUCT.PRODUCTION_MONTH,PRODUCT.MODEL_CD,CLAIM.EVENT_TYPE_CD,PRODUCT.SELLING_DEALER_CD,PRODUCT.CSTMR_COUNTRY_CD'
    
    print('Dispatching Fixed Pareto...')
    await run_pareto_analysis(
        name='Phase 1 - Pareto Alert 2 Fixed',
        data_selection_id=ds_id,
        folder_id=folder_id,
        ctx=ctx,
        report_var=report_var,
        wait_for_completion=False
    )
    print('Dispatching Fixed Stat Driver...')
    await run_statistical_driver_analysis(
        name='Phase 2 - Stat Driver Alert 2 Fixed',
        data_selection_id=ds_id,
        folder_id=folder_id,
        ctx=ctx,
        report_var=report_var,
        wait_for_completion=False
    )
    print('Done!')
asyncio.run(main())

