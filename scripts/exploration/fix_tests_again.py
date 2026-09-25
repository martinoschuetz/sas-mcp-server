with open('tests/test_viya_utils.py', 'r', encoding='utf-8') as f:
    tt_content = f.read()

tt_content = tt_content.replace('patch("sas_mcp_server.viya_client.httpx.AsyncClient")', 'patch("sas_mcp_server.viya_client._PersistentAsyncClient")')

with open('tests/test_viya_utils.py', 'w', encoding='utf-8') as f:
    f.write(tt_content)
print('Fixed test_viya_utils.py')
