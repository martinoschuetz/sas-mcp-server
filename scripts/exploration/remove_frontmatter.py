
import os
import re

rules_dir = r'.agents/rules'
for filename in os.listdir(rules_dir):
    if filename.endswith('.md'):
        filepath = os.path.join(rules_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Remove frontmatter if it exists at the start (ignoring leading whitespace)
        new_content = re.sub(r'^\s*---\s*\n.*?\n---\s*\n', '', content, flags=re.DOTALL)
        
        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f'Removed frontmatter from {filename}')

