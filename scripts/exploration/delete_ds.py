import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if a.get('dataSelectionId') == 'd4dbfefc-4eda-4455-baa9-48462446fcef':
                await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a["id"]}', headers={'Authorization': f'Bearer {token}'})
                print('Deleted analysis', a.get('id'))
        d_res = await client.delete('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/d4dbfefc-4eda-4455-baa9-48462446fcef', headers={'Authorization': f'Bearer {token}'})
        print('Deleted DS 0075', d_res.status_code)
asyncio.run(main())
