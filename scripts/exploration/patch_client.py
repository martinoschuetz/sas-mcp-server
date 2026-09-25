import re

with open('src/sas_mcp_server/viya_client.py', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
class _PersistentAsyncClient(httpx.AsyncClient):
    async def __aenter__(self):
        return self
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass

_CLIENT_CACHE: dict[str, _PersistentAsyncClient] = {}

def make_client(token: str | None) -> httpx.AsyncClient:
    \"\"\"Create or retrieve a persistent :class:httpx.AsyncClient with auth headers for Viya API calls.\"\"\"
    headers: dict[str, str] = {}
    if token:
        if not token.startswith("Bearer "):
            token = f"Bearer {token}"
        headers["Authorization"] = token
    
    cache_key = token or "anon"
    
    # Cap cache to prevent memory leaks from rolling tokens
    if len(_CLIENT_CACHE) > 10:
        _CLIENT_CACHE.clear()
        
    if cache_key not in _CLIENT_CACHE:
        _CLIENT_CACHE[cache_key] = _PersistentAsyncClient(
            headers=headers, verify=SSL_VERIFY, timeout=_CLIENT_TIMEOUT
        )
    return _CLIENT_CACHE[cache_key]
'''

pattern = re.compile(r'def make_client\(token: str \| None\) -> httpx\.AsyncClient:\n.*?(?=\ndef return_items)', re.DOTALL)
if pattern.search(content):
    content = pattern.sub(replacement.strip() + '\n\n', content)
    with open('src/sas_mcp_server/viya_client.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Patched make_client')
else:
    print('Could not find make_client')
