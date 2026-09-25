import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Copy the 'Phase 3 - Broad Workmanship Cohort'
        aid = '886fdea7-cf5d-499d-9748-4559065fdac2'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds = chk.json()
        del ds['id']
        del ds['creationTimeStamp']
        del ds['modifiedTimeStamp']
        ds['name'] = 'Alert 1 Broad Cohort'
        ds['description'] = 'Broad cohort (Galacto USA) to run Association Rules for Alert 1 Workmanship without single-part constraints.'
        
        # Post the new DS
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=ds)
        new_ds = res.json()
        print('Created DS ID:', new_ds.get('id'))
        
        # Launch it
        await client.post(f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_ds.get('id')}/jobs", headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.job.execution.job.request+json', 'Accept': 'application/vnd.sas.job.execution.job+json'})
asyncio.run(main())
