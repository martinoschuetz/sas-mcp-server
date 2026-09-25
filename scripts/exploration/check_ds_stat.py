
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print(res.json().get('displayStatus'))
asyncio.run(main())

