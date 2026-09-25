import asyncio
import os
import json
import httpx
from unittest.mock import MagicMock
import sas_mcp_server.tools._common
import sas_mcp_server.tools.compute

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

sas_mcp_server.tools.compute.get_token = get_token

async def main():
    token = await get_token()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
    
    # 1. Get Phase 2 Analyses
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers=headers)
        analyses_data = res.json().get('items', [])
        
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    
    tree_analysis = None
    stat_analysis = None
    
    for a in sorted(analyses_data, key=lambda x: x.get('creationTimeStamp', ''), reverse=True):
        name = a.get('name', '')
        if a.get('dataSelectionId') == ds_id:
            if 'Phase 2 - Decision Tree' in name and tree_analysis is None:
                tree_analysis = a
            elif 'Phase 2 - Stat Driver' in name and stat_analysis is None:
                stat_analysis = a
                
    print(f"Tree Short ID: {tree_analysis.get('shortId')}")
    print(f"Stat Short ID: {stat_analysis.get('shortId')}")
    
    # 2. Extract Top Driver from Stat Driver
    # The table is usually ANL_{shortId}_STAT_DRIVER
    stat_short = stat_analysis.get('shortId')
    tree_short = tree_analysis.get('shortId')
    
    sas_code = f"""
    cas mysess;
    proc fedsql sessref=mysess;
      create table casuser.top_stat as
      select "VARIABLE", "IMPORTANCE" from QASANLOUT."STAT_DRIVER_{stat_short}"
      order by "IMPORTANCE" desc limit 1;
      
      create table casuser.top_leaf as
      select * from QASANLOUT."DT_NODES_{tree_short}"
      where "LEAF" = 1
      order by "CLAIMCOST" desc limit 1;
    quit;
    
    filename out1 TEMP;
    proc json out=out1; export casuser.top_stat; run;
    data _null_; infile out1; input; put "STAT_JSON:" _infile_ ":STAT_JSON"; run;
    
    filename out2 TEMP;
    proc json out=out2; export casuser.top_leaf; run;
    data _null_; infile out2; input; put "TREE_JSON:" _infile_ ":TREE_JSON"; run;
    """
    
    class Ctx: pass
    ctx = Ctx()
    ctx.request_context = MagicMock()
    
    mcp_mock = MagicMock()
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
    mcp_mock.tool.side_effect = mock_tool
    sas_mcp_server.tools.compute.register(mcp_mock, get_token)
    execute_sas = tools['execute_sas_code']
    
    res_sas = await execute_sas(sas_code=sas_code, ctx=ctx)
    log = res_sas.get('log', '')
    if res_sas.get('state') == 'error':
        print("SAS ERROR!")
        print(log)
    else:
        for line in log.split('\\n'):
            if 'STAT_JSON:' in line:
                print("STAT:", line)
            if 'TREE_JSON:' in line:
                print("TREE:", line)

if __name__ == '__main__':
    asyncio.run(main())
