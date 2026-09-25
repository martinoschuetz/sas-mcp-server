
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Copy Alert 2 DS
        name = 'Phase 3 - Broad Workmanship Cohort v2'
        body_copy = {'name': name}
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd/copy', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body_copy)
        if res.status_code != 201:
            print('Copy failed:', res.text)
            return
            
        new_id = res.json().get('id')
        print('Copied as ID:', new_id)
        
        # Get its Etag and details
        res2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds = res2.json()
        etag = res2.headers.get('Etag')
        
        # Remove PRIM_REPL_PART_CD
        filters = ds.get('filterCriteria', {}).get('0', [])
        new_filters = [f for f in filters if f.get('columnName') != 'PRIM_REPL_PART_CD']
        ds['filterCriteria']['0'] = new_filters
        
        # Update it
        res3 = await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json', 'If-Match': etag}, json=ds)
        if res3.status_code != 200:
            print('Update failed:', res3.text)
            return
            
        print('Updated successfully.')
        
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
            
        print('Ready to launch:', new_id)

asyncio.run(main())

