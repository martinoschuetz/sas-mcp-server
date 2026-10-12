import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    data = json.loads(text.strip())
    items = data.get('items', [])
    for i, item in enumerate(items):
        line = item.get('line', '')
        if 'PROC HTTP' in line or 'proc http' in line.lower():
            print(f"--- HTTP CALL at {i} ---")
            for j in range(max(0, i-5), min(len(items), i+8)):
                print(f"[{items[j].get('type')}] {items[j].get('line')}")
