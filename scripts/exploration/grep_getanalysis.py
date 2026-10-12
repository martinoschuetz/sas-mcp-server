import json
with open('scripts/exploration/step2_log_v2.txt', 'r') as f:
    text = f.read()
    data = json.loads(text.strip())
    items = data.get('items', [])
    for i, item in enumerate(items):
        line = item.get('line', '')
        if 'anl_getanalysisattributes' in line.lower() or 'mfgapp.analysis_ins' in line.lower():
            print(f"--- MATCH at {i} ---")
            for j in range(max(0, i-2), min(len(items), i+3)):
                print(f"[{items[j].get('type')}] {items[j].get('line')}")
