
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res1 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/5767ab0b-62b1-4bce-997f-10372f727813', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print('Workmanship DS:', res1.json().get('displayStatus'))
        res2 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/05efb085-ce9c-40c0-9e3c-c2e5ff096d98', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print('Hardware DS:', res2.json().get('displayStatus'))
asyncio.run(main())

