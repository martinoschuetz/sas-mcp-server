import re

# 1. Add clear_client_cache to viya_client.py
with open('src/sas_mcp_server/viya_client.py', 'r', encoding='utf-8') as f:
    content = f.read()

if 'def clear_client_cache():' not in content:
    content = content.replace('def make_client', 'def clear_client_cache():\n    _CLIENT_CACHE.clear()\n\ndef make_client')
    with open('src/sas_mcp_server/viya_client.py', 'w', encoding='utf-8') as f:
        f.write(content)

# 2. Fix test_tools.py mock
with open('tests/test_tools.py', 'r', encoding='utf-8') as f:
    tt_content = f.read()

tt_content = tt_content.replace('patch("sas_mcp_server.viya_client.httpx.AsyncClient")', 'patch("sas_mcp_server.viya_client._PersistentAsyncClient")')
with open('tests/test_tools.py', 'w', encoding='utf-8') as f:
    f.write(tt_content)

# 3. Add autouse fixture to conftest.py to clear cache
with open('tests/conftest.py', 'r', encoding='utf-8') as f:
    ct_content = f.read()

if 'clear_client_cache' not in ct_content:
    ct_content += '''
import pytest
@pytest.fixture(autouse=True)
def _clear_viya_client_cache():
    from sas_mcp_server.viya_client import clear_client_cache
    clear_client_cache()
'''
    with open('tests/conftest.py', 'w', encoding='utf-8') as f:
        f.write(ct_content)

print("Test fixes applied.")
