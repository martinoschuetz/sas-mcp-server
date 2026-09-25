import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
        
        # Get all analyses linked to this DS
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'})
        for a in res.json().get('items', []):
            if a.get('dataSelectionId') == aid:
                print('Deleting Analysis:', a.get('name'))
                await client.delete(f"https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get('id')}", headers={'Authorization': f'Bearer {token}'})

asyncio.run(main())
