import json

with open("C:/Git/sas-mcp-server/full_log.txt", "r") as f:
    data = json.load(f)
    
items = data.get('items', [])
for i, item in enumerate(items):
    line = item.get('line', '')
    typ = item.get('type', '').upper()
    if typ in ('ERROR', 'WARNING'):
        print(f"[{i}] {typ}: {line}")
