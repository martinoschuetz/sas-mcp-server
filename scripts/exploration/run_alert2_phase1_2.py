
import asyncio, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
from sas_mcp_server.tools.iot import run_pareto_analysis, run_statistical_driver_analysis
from mcp.server.fastmcp import Context
from unittest.mock import MagicMock

async def main():
    ctx = MagicMock()
    ds_id = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
    
    print('Dispatching Pareto...')
    pareto_task = asyncio.create_task(
        run_pareto_analysis(
            name='Phase 1 - Pareto Alert 2',
            data_selection_id=ds_id,
            ctx=ctx,
            wait_for_completion=False
        )
    )
    
    print('Dispatching Stat Driver...')
    stat_task = asyncio.create_task(
        run_statistical_driver_analysis(
            name='Phase 2 - Stat Driver Alert 2',
            data_selection_id=ds_id,
            ctx=ctx,
            wait_for_completion=False
        )
    )
    
    res1 = await pareto_task
    res2 = await stat_task
    print('Pareto:', res1)
    print('Stat Driver:', res2)

asyncio.run(main())

