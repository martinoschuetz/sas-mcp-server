
import json
import re

col_labels = {}
# Read fqa_vars from earlier (if available) - let's fetch it via API instead
import asyncio, httpx, os
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res_cols = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/tables/columns?limit=10000', headers={'Authorization': f'Bearer {token}'})
        for c in res_cols.json().get('items', []):
            col = c.get('name')
            label = c.get('displayLabel', c.get('label', ''))
            col_labels[col] = label
            
    with open('C:/Users/germsz/.gemini/antigravity-cli/brain/51995ee4-f7b5-4d66-904d-425adf7b950f/.system_generated/steps/18784/output.txt', 'r') as f:
        data = json.load(f)
        listing = data.get('listing', '')
        
    lines = listing.split('\n')
    
    current_table = ''
    markdown = '# FQA Data Mart Dictionary\n\nThis document provides an overview of available variables and their cardinalities (distinct values) in the FQA data mart (QASMartStore). This is crucial for dynamic routing because we can immediately see which variables are valid and whether they have sufficient variation (cardinality) to be used as Statistical Drivers (e.g. CSTMR_STATE_CD has 64 distinct values, while CSTMR_COUNTRY_CD has only 5).\n\n'
    
    in_table = False
    
    for line in lines:
        if 'Distinct Counts for PRODUCT' in line:
            current_table = 'PRODUCT'
            markdown += '## PRODUCT Dimension\n| Column | Label | Distinct Values | Missing Values |\n|---|---|---|---|\n'
            in_table = True
        elif 'Distinct Counts for CLAIM' in line:
            current_table = 'CLAIM'
            markdown += '\n## CLAIM Dimension\n| Column | Label | Distinct Values | Missing Values |\n|---|---|---|---|\n'
            in_table = True
        elif 'Distinct Counts for LABOR' in line:
            current_table = 'LABOR'
            markdown += '\n## LABOR Dimension\n| Column | Label | Distinct Values | Missing Values |\n|---|---|---|---|\n'
            in_table = True
        elif 'Distinct Counts for PART' in line:
            current_table = 'PART'
            markdown += '\n## PART Dimension\n| Column | Label | Distinct Values | Missing Values |\n|---|---|---|---|\n'
            in_table = True
        elif in_table:
            # Parse the row
            m = re.search(r'^\s*([A-Za-z0-9_]+)\s+(\d+)\s+(\d+)', line)
            if m:
                col = m.group(1)
                dist = m.group(2)
                miss = m.group(3)
                label = col_labels.get(col, '')
                markdown += f'| {col} | {label} | {dist} | {miss} |\n'
                
    artifact_path = 'C:/Users/germsz/.gemini/antigravity-cli/brain/51995ee4-f7b5-4d66-904d-425adf7b950f/fqa_data_mart_dictionary.md'
    with open(artifact_path, 'w', encoding='utf-8') as f:
        f.write(markdown)
    print('Artifact generated at:', artifact_path)

asyncio.run(main())

