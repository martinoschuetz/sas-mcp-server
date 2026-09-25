
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        ds_full = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/48dc036d-1417-4469-9315-c806ad41bcec', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print(json.dumps(ds_full.json(), indent=2))
asyncio.run(main())

