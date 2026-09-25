
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 DS
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}'})
        ds = res.json()
        
        # Create new DS
        body = {
            'name': 'Alert 2 Analysis Base DS 6',
            'creationType': 'DEFAULT',
            'filterCriteria': ds.get('filterCriteria', {}),
            'additionalAttributes': ds.get('additionalAttributes', [])
        }
        
        res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
        print('Status:', res2.status_code)
        if res2.status_code == 201:
            new_id = res2.json().get('id')
            print('New DS:', new_id)
            
            # Launch it
            launch_payload = {
                'launchColumnTables': ['PRODUCT', 'CLAIM', 'LABOR', 'PART'], 
                'transposeFlag': 0, 
                'launchKeyDim': 'PRODUCT',
                'tableName': f"DS_{new_id.replace('-', '_')[:24]}",
                'launchAppName': 'CAS'
            }
            res3 = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}, json=launch_payload)
            print('Launch Status:', res3.status_code)
            if res3.status_code != 201:
                print(res3.text)
        else:
            print(res2.text)
asyncio.run(main())

