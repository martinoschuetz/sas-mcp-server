
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = 'f92e06ba-8d75-4abb-bfc4-4ae034b9ceb4'
        await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}'})
        print('Deleted Phase 3')
asyncio.run(main())

