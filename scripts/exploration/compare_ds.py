
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        ds1 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/48dc036d-1417-4469-9315-c806ad41bcec', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds2 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/5762fc6f-a95a-4897-9575-b80ff033db9c', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print('0075 parent:', ds1.json().get('additionalAttributes'))
        print('c91a parent:', ds2.json().get('additionalAttributes'))
asyncio.run(main())

