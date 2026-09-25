import asyncio, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
from sas_mcp_server.tools.compute import execute_sas_code
from mcp.server.fastmcp import Context
from unittest.mock import MagicMock

async def main():
    ctx = Context(request_context=MagicMock())
    code = '''
proc fedsql sessref=casauto;
   select CSTMR_STATE_CD, count(*) as cnt 
   from qasaldat.DS_21274abd_7d03_4ac6_84e3_PRODUCT
   group by CSTMR_STATE_CD 
   order by cnt desc limit 10;
quit;
'''
    res = await execute_sas_code(code, ctx)
    print(res)
asyncio.run(main())
