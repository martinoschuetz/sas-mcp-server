import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=100', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if a.get('name') == 'StatDriverTest123':
                print('Deleting', a.get('id'))
                await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get("id")}', headers={'Authorization': f'Bearer {token}'})
asyncio.run(main())
