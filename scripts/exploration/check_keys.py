
import json
data = json.load(open('C:/Users/germsz/.gemini/antigravity-cli/brain/51995ee4-f7b5-4d66-904d-425adf7b950f/.system_generated/steps/19228/output.txt'))
items = data.get('items', [])
items.sort(key=lambda x: x.get('score', 0), reverse=True)
print(items[2].keys())
print(items[2])

