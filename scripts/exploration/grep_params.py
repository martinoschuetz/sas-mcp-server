import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    try:
        data = json.loads(text.strip())
        items = data.get('items', [])
        for item in items:
            line = item.get('line', '')
            if 'STABLE_PERIOD' in line or 'PARAMS_TYPES' in line or 'G_STABLE_PERIOD' in line:
                print(f"[{item.get('type')}] {line}")
    except Exception as e:
        print("Error parsing json:", e)
