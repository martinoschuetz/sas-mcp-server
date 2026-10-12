import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    try:
        data = json.loads(text.strip())
        items = data.get('items', [])
        for i, item in enumerate(items):
            if item.get('type') == 'error':
                print("--- ERROR CONTEXT ---")
                for j in range(max(0, i-5), min(len(items), i+3)):
                    print(f"[{items[j].get('type')}] {items[j].get('line')}")
                break
    except Exception as e:
        print("Error parsing json:", e)
