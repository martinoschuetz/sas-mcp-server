import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'})
        for a in res.json().get('items', []):
            if a.get('dataSelectionId') == aid:
                print('Deleting:', a.get('name'))
                await client.delete(f"https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get('id')}", headers={'Authorization': f'Bearer {token}'})
asyncio.run(main())
