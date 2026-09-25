
import os

base_dir = r'C:\Users\germsz\OneDrive - SAS\Desktop\FQA_MCP'
fqa_guide_path = os.path.join(base_dir, 'FQA_Users_Guide.md')
prompts_path = os.path.join(base_dir, 'FQA_CoPilot_Promts.md')
high_card_path = os.path.join(base_dir, 'fqa_high_cardinality_plan.md')
output_path = os.path.join(base_dir, 'FQA_MCP_Users_Guide.md')

with open(fqa_guide_path, 'r', encoding='utf-8') as f:
    fqa_guide = f.read()

with open(prompts_path, 'r', encoding='utf-8') as f:
    prompts = f.read()

with open(high_card_path, 'r', encoding='utf-8') as f:
    high_card = f.read()

# Build the new content
new_content = f'{fqa_guide}\n\n'
new_content += '## Handling High Cardinality Variables\n\n'
new_content += f'{high_card}\n\n'
new_content += '## Example Prompts\n\n'
new_content += f'{prompts}\n'

with open(output_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f'Successfully wrote {output_path}')

