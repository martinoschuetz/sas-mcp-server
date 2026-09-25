import asyncio, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
from sas_mcp_server.tools.iot import run_pareto_analysis, run_statistical_driver_analysis
async def main():
    ctx = None
    ds_id = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
    
    print('Dispatching Pareto...')
    try:
        res1 = await run_pareto_analysis(
            name='Phase 1 Pareto Alert 2',
            data_selection_id=ds_id,
            ctx=ctx,
            wait_for_completion=False
        )
        print('Pareto:', res1)
    except Exception as e:
        print('Pareto Error:', e)
        
    print('Dispatching Stat Driver...')
    try:
        res2 = await run_statistical_driver_analysis(
            name='Phase 2 Stat Driver Alert 2',
            data_selection_id=ds_id,
            ctx=ctx,
            wait_for_completion=False
        )
        print('Stat Driver:', res2)
    except Exception as e:
        print('Stat Error:', e)

asyncio.run(main())
