import json

with open(r'C:\Users\germsz\.gemini\antigravity-cli\brain\51995ee4-f7b5-4d66-904d-425adf7b950f\.system_generated\steps\15859\output.txt', 'r') as f:
    data = json.load(f)

items = data.get('items', [])
print(f"Total returned: {len(items)}, total in run: {data.get('total')}")

items.sort(key=lambda x: float(x.get('cost_score', 0) or 0), reverse=True)
for i, item in enumerate(items[:5]):
    print(f"{i+1}. **Part:** {item.get('PRIM_REPL_PART_CD')} - {item.get('PRIM_REPL_PART_CD_DESC')} | **Model:** {item.get('MODEL_CD')} ({item.get('MODEL_CD_DESC')}) | **Cost Score:** {item.get('cost_score', 0):.2f} | **Alert Duration:** {item.get('alert_start_date')} to {item.get('alert_end_date')} ({item.get('Alert_Duration_MONTH')} months) | **Score:** {item.get('score'):.2f}")
