import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 1
        aid = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds = chk.json()
        del ds['id']
        del ds['creationTimeStamp']
        del ds['modifiedTimeStamp']
        ds['name'] = 'Alert 3 Galacto 3-033 DS'
        ds['description'] = 'Data selection for Alert 3 (Galacto 3-033)'
        
        # Modify the filter for Part
        for f in ds.get('filterCriteria', {}).get('0', []):
            if f['columnName'] == 'PRIM_REPL_PART_CD':
                f['values'] = ['3-033']
                del f['id']
            elif 'id' in f:
                del f['id']
        
        # Post the new DS
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=ds)
        new_ds = res.json()
        print('Created DS ID:', new_ds.get('id'))
        
        # Launch it
        await client.post(f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_ds.get('id')}/jobs", headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.job.execution.job.request+json', 'Accept': 'application/vnd.sas.job.execution.job+json'})
asyncio.run(main())
