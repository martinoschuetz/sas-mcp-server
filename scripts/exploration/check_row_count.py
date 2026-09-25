import asyncio
import os
import json
import uuid
from unittest.mock import MagicMock
import sas_mcp_server.tools.compute

class DummyContext:
    def __init__(self):
        self.request_context = MagicMock()

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

sas_mcp_server.tools._common.get_token = get_token
sas_mcp_server.tools.compute.get_token = get_token

async def main():
    ctx = DummyContext()
    mcp_mock = MagicMock()
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
    mcp_mock.tool.side_effect = mock_tool
    sas_mcp_server.tools.compute.register(mcp_mock, get_token)
    
    execute_sas_code = tools['execute_sas_code']
    
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    table_name = f"DS_{ds_id.replace('-', '_')[:24]}"
    
    code = f"""
    cas mysess;
    proc casutil;
      list table="{table_name}" incaslib="casuser";
    run;
    proc fedsql sessref=mysess;
      select count(*) as row_count from casuser."{table_name}";
    quit;
    """
    
    res = await execute_sas_code(sas_code=code, ctx=ctx)
    print(res)

if __name__ == '__main__':
    asyncio.run(main())
