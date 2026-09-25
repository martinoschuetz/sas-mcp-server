import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get all analyses
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if 'Phase 3' in a.get('name') or 'Broad' in a.get('name'):
                print('Deleting Analysis:', a.get('name'))
                await client.delete(f"https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get('id')}", headers={'Authorization': f'Bearer {token}'})
        
        # Get all DS
        res2 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for d in res2.json().get('items', []):
            if 'Phase 3' in d.get('name') or 'Broad' in d.get('name') or 'Workmanship' in d.get('name') or 'Hardware' in d.get('name'):
                print('Deleting DS:', d.get('name'))
                await client.delete(f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{d.get('id')}", headers={'Authorization': f'Bearer {token}'})

asyncio.run(main())
