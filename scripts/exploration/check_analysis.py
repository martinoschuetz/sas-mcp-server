
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid1 = '03860d37-6bb8-4f73-8a60-7d4a9a19ffed'
        r1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid1}', headers={'Authorization': f'Bearer {token}'})
        print(r1.json())
asyncio.run(main())

