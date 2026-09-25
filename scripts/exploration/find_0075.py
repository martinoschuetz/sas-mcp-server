import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'})
        for ds in res.json().get('items', []):
            if '0075' in ds.get('name', ''):
                print(f"Found DS: {ds.get('name')} ID: {ds.get('id')}")
                ds_full = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{ds.get("id")}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
                print(json.dumps(ds_full.json().get('additionalAttributes', []), indent=2))
                print(json.dumps(ds_full.json().get('filterCriteria', {}), indent=2))
asyncio.run(main())
