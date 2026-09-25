
from sas_mcp_server.tools.compute import execute_sas_code
import asyncio

class Ctx: pass
ctx = Ctx()
async def get_token(ctx):
    import json, os
    return json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
import sas_mcp_server.tools.compute
sas_mcp_server.tools.compute.get_token = get_token

async def main():
    sas_code = '''
    cas mySess;
    caslib _all_ assign;
    proc fedsql sessref=mySess;
       select count(*) as sequence_count
       from CASUSER.DS_61631588_5dcf_48da_a12a_ a
       join CASUSER.DS_61631588_5dcf_48da_a12a_ b
         on a.PRODUCT_ID = b.PRODUCT_ID
       where a.PRIM_LABOR_CD = 'I-011'
         and b.PRIM_LABOR_CD = 'I-007'
         and a.EVENT_SUBMIT_DATE < b.EVENT_SUBMIT_DATE;
    quit;
    '''
    res = await execute_sas_code(sas_code, ctx)
    print(res.get('listing', ''))
asyncio.run(main())

