
import json
import glob
for f in glob.glob('C:/Users/germsz/.gemini/antigravity-cli/brain/51995ee4-f7b5-4d66-904d-425adf7b950f/.system_generated/logs/transcript_full.jsonl'):
    with open(f, 'r', encoding='utf-8') as fp:
        for line in fp:
            try:
                d = json.loads(line)
                if d.get('source') == 'USER_EXPLICIT':
                    content = d.get('content', '')
                    if 'esp' in content.lower() or 'forecast' in content.lower() or 'book' in content.lower() or 'link' in content.lower():
                        print('---')
                        print(content)
            except:
                pass

