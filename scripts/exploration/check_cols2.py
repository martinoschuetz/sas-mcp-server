
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/tables/columns?limit=1', headers={'Authorization': f'Bearer {token}'})
        print(json.dumps(res.json().get('items')[0], indent=2))
asyncio.run(main())

