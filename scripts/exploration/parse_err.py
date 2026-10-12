import json
with open('scripts/exploration/step2_log.txt', 'r') as f:
    text = f.read()
    try:
        data = json.loads(text.strip())
        for item in data.get('items', []):
            if item.get('type') == 'error':
                print(item.get('line'))
    except Exception as e:
        print("Error parsing json:", e)
