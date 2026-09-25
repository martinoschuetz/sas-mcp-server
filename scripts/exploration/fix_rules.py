
import os

for file in ['api.md', 'esp.md', 'forecasting.md']:
    path = os.path.join('.agents', 'rules', file)
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if not content.startswith('---'):
        content = '---\ntrigger: always_on\n---\n\n' + content
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)

