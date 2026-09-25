import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'})
        for ds in res.json().get('items', []):
            if 'Top States' in ds.get('name', ''):
                print(f"DS: {ds.get('name')} ID: {ds.get('id')}")
asyncio.run(main())
