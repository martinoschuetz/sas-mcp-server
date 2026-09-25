import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if a.get('state') == 'failed':
                print(f"Deleting broken analysis: {a.get('name')}")
                await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a["id"]}', headers={'Authorization': f'Bearer {token}'})
asyncio.run(main())
