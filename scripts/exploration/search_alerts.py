import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for ds in res.json().get('items', []):
            if 'Alert' in ds.get('name', '') or 'alert' in ds.get('name', '').lower():
                print(f"DS: {ds.get('name')} ID: {ds.get('id')}")
asyncio.run(main())
