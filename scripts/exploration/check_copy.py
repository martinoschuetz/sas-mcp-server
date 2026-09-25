
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/21274abd-7d03-4ac6-84e3-3c92084e6b6c/copy', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'name': 'Test Copy 1'})
        print(res.status_code)
        print(res.text)
asyncio.run(main())

