
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 to copy its JSON structure exactly
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds = res.json()
        
        # Remove the PRIM_REPL_PART_CD filter
        filters = ds.get('filterCriteria', {}).get('0', [])
        new_filters = [f for f in filters if f.get('columnName') != 'PRIM_REPL_PART_CD']
        ds['filterCriteria']['0'] = new_filters
        
        # Create new DS body
        name = 'Phase 3 - Broad Workmanship Cohort'
        body = {
            'name': name,
            'creationType': 'EIENTERPRISE_PRODUCT',
            'filterCriteria': ds.get('filterCriteria'),
            'additionalAttributes': ds.get('additionalAttributes', [])
        }
        # Post it!
        res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
        if res2.status_code != 201:
            print('Failed to create DS:', res2.text)
            return
        
        new_id = res2.json().get('id')
        print(f'Created {name} with ID: {new_id}')

        # Move it to the project folder 'MCP Test'
        folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
        if folder_id:
            member_body = {
                'name': name,
                'uri': f'/dataSelection/dataSelections/{new_id}',
                'contentType': 'application/vnd.sas.data.selection+json'
            }
            await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/folders/folders/{folder_id}/members', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.content.folder.member+json'}, json=member_body)
            print('Moved to folder.')

asyncio.run(main())

