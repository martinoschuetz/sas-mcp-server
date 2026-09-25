import asyncio
import os
import json
from unittest.mock import MagicMock
import sas_mcp_server.tools.compute

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        return json.load(f)['Default']['access-token']

sas_mcp_server.tools.compute.get_token = get_token

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
    
    execute_sas = tools['execute_sas_code']
    
    code = """
    cas mySession sessopts=(metrics=true);
    libname qasanl cas caslib="QASANLOUT";
    
    proc print data=qasanl.STATDRIVER_IMPLIST_CAE1EAFD(obs=5); run;
    
    proc sql;
        select memname from dictionary.tables where libname='QASANLOUT' and memname like '%446ADE4A%';
    quit;
    
    proc print data=qasanl.RELIAB_ESTIMATES_446ADE4A(obs=10); run;
    
    cas mySession terminate;
    """
    
    class Ctx: pass
    ctx = Ctx()
    
    print('Executing SAS code to fetch FQA results...')
    res = await execute_sas(sas_code=code, ctx=ctx)
    with open("sas_output.txt", "w", encoding="utf-8") as f:
        import json
        f.write(json.dumps(res, indent=2))

if __name__ == '__main__':
    asyncio.run(main())
