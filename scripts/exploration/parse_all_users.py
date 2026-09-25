
import json
import glob
import os

res = []
for f in glob.glob('C:/Users/germsz/.gemini/antigravity-cli/brain/*/.system_generated/logs/transcript_full.jsonl'):
    with open(f, 'r', encoding='utf-8') as fp:
        for line in fp:
            try:
                d = json.loads(line)
                if d.get('source') == 'USER_EXPLICIT':
                    content = d.get('content', '')
                    cl = content.lower()
                    if 'esp' in cl or 'event stream' in cl or 'forecast' in cl or 'book' in cl or 'link' in cl:
                        res.append(f'[{os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(f))))}]\n{content}')
            except:
                pass

with open('user_esp_forecast_context.txt', 'w', encoding='utf-8') as f:
    for r in res:
        f.write('---\n' + r + '\n')

