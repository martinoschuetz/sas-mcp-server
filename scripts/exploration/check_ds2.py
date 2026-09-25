
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for d in res.json().get('items', []):
            print(d.get('name'), d.get('id'))
asyncio.run(main())

