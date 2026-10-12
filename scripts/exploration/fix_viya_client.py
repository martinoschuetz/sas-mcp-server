import re

filepath = r"src/sas_mcp_server/viya_client.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Fix the first conflict (docstring)
content = re.sub(
    r"<<<<<<< HEAD\n\s*\"\"\"Create or retrieve a persistent :class:httpx\.AsyncClient with auth headers for Viya API calls\.\"\"\"\n=======\n(.*?)\n>>>>>>> david/main",
    r"\1",
    content,
    flags=re.DOTALL
)

# Fix the second conflict (client instantiation)
replacement = '''    
    cache_key = token or "anon"
    
    # Cap cache to prevent memory leaks from rolling tokens
    if len(_CLIENT_CACHE) > 10:
        _CLIENT_CACHE.clear()
        
    if cache_key not in _CLIENT_CACHE:
        _CLIENT_CACHE[cache_key] = _PersistentAsyncClient(
            headers=headers, 
            verify=SSL_VERIFY, 
            timeout=_CLIENT_TIMEOUT,
            event_hooks=http_debug.event_hooks()
        )
    return _CLIENT_CACHE[cache_key]
'''
content = re.sub(
    r"<<<<<<< HEAD\n\s*cache_key = token.*?return _CLIENT_CACHE\[cache_key\]\n=======\n.*?return httpx\.AsyncClient\(.*?event_hooks=http_debug\.event_hooks\(\),\n\s*\)\n>>>>>>> david/main",
    replacement,
    content,
    flags=re.DOTALL
)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
