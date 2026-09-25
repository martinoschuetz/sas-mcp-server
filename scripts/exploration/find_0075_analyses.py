import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if '0075' in a.get('name', ''):
                print(f"Analysis: {a.get('name')} ID: {a.get('id')} DS: {a.get('dataSelectionId')}")
asyncio.run(main())
