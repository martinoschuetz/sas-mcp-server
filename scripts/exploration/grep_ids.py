import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    data = json.loads(text.strip())
    items = data.get('items', [])
    for item in items:
        line = item.get('line', '')
        if 'G_INSTANCEID resolves to' in line or 'G_ANALYSISID resolves to' in line or 'BASE_URI_CREDENTIALS resolves to' in line:
            print(f"[{item.get('type')}] {line}")
