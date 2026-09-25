import asyncio, os, json
from unittest.mock import MagicMock
import sas_mcp_server.tools.compute

async def get_token(ctx=None):
    return json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']

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
    libname qasms cas caslib="QASMartStore";
    proc sql outobs=3;
        select CSTMR_STATE_CD, count(*) as count
        from qasms.CLAIM_EN_MASTER_MIN
        where MODEL_CD = 'Galacto' and PRIM_LABOR_CD = '9-040'
        group by CSTMR_STATE_CD
        order by count desc;
    quit;
    cas mySession terminate;
    """
    class Ctx: pass
    res = await execute_sas(sas_code=code, ctx=Ctx())
    with open('top_states.json', 'w', encoding='utf-8') as f:
        f.write(json.dumps(res, indent=2))
        
if __name__ == "__main__":
    asyncio.run(main())
