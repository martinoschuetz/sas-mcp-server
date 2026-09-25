
import asyncio, httpx, os, json, datetime
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/casManagement/servers/cas-shared-default/caslibs/QASANLOUT/tables?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for tbl in res.json().get('items', []):
            if tbl.get('name'):
                print(tbl.get('name'))
asyncio.run(main())

