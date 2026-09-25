
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        print(json.dumps(res.json().get('filterCriteria'), indent=2))
asyncio.run(main())

