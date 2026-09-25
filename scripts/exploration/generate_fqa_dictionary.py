
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get column labels
        res_cols = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/tables/columns?limit=10000', headers={'Authorization': f'Bearer {token}'})
        col_labels = {}
        for c in res_cols.json().get('items', []):
            table = c.get('tableMetaId')
            col = c.get('name')
            label = c.get('displayLabel', c.get('label', ''))
            col_labels[f'{table}.{col}'] = label
            
        tables = ['PRODUCT', 'CLAIM', 'LABOR', 'PART']
        markdown = '# FQA Data Mart Dictionary\n\n'
        markdown += 'This document provides a comprehensive overview of all available variables and their Cardinalities in the FQA data mart (QASMartStore).\n\n'
        
        for table in tables:
            print(f'Fetching distinct counts for {table}...')
            payload = {'table': {'name': table, 'caslib': 'QASMartStore'}}
            res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions/casauto/actions/simple.distinct', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json=payload)
            if res.status_code == 400 and 'Unknown session' in res.text:
                # create session
                res_sess = await client.post('https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={})
                sess_id = res_sess.json().get('session')
                res = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions/{sess_id}/actions/simple.distinct', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json=payload)
            
            data = res.json()
            results = data.get('results', {}).get('Distinct', {}).get('rows', [])
            
            markdown += f'## {table} Dimension\n'
            markdown += '| Column Name | Label | Distinct Values | Missing Values |\n'
            markdown += '|-------------|-------|-----------------|----------------|\n'
            for r in results:
                col_name = r[0]
                distinct = r[1]
                missing = r[2]
                label = col_labels.get(f'{table}.{col_name}', '')
                markdown += f'| {table}.{col_name} | {label} | {distinct} | {missing} |\n'
            markdown += '\n'
            
        with open('fqa_data_model_dictionary.md', 'w') as f:
            f.write(markdown)
asyncio.run(main())

