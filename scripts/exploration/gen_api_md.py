
import os
import datetime

with open('.agents/rules/api.md', 'w', encoding='utf-8') as f:
    f.write('# SAS Viya APIs Documentation Directory\n\n')
    f.write('**Version:** 2026.09\n\n')
    f.write('The docs/APIs directory contains OpenAPI specifications and documentation for various SAS Viya endpoints, organized by category.\n\n')
    
    base_dir = r'docs/APIs'
    if not os.path.exists(base_dir):
        print('Directory not found')
        exit(1)
        
    for category in sorted(os.listdir(base_dir)):
        cat_path = os.path.join(base_dir, category)
        if os.path.isdir(cat_path) and category != 'old':
            f.write(f'## {category}\n')
            files = [file for file in os.listdir(cat_path) if file.endswith('.yml')]
            if files:
                f.write('<ul>\n')
                for file in sorted(files):
                    f.write(f'  <li><code>{file}</code></li>\n')
                f.write('</ul>\n\n')
            else:
                f.write('*No .yml files currently mapped to this category.*\n\n')
    
    f.write('## Uncategorized / Old\n')
    f.write('There is an old directory containing unorganized or legacy YML files, and some files at the root of docs/APIs.\n')

