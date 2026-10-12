import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    data = json.loads(text.strip())
    items = data.get('items', [])
    for i, item in enumerate(items):
        line = item.get('line', '')
        if 'GLOBAL G_STABLE_PERIOD' in line and item.get('type') == 'normal':
            print(f"--- MATCH at {i} ---")
            for j in range(max(0, i-5), min(len(items), i+15)):
                print(f"[{items[j].get('type')}] {items[j].get('line')}")
            break
