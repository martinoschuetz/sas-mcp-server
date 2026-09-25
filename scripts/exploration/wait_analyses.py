
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid1 = '03860d37-6bb8-4f73-8a60-7d4a9a19ffed'
        aid2 = '6e093154-357d-46fa-a2f3-cf320305d6ed'
        while True:
            r1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid1}/steps', headers={'Authorization': f'Bearer {token}'})
            if r1.json().get('items'):
                print('Phase 1:', r1.json()['items'][0].get('status'))
            
            r2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid2}/steps', headers={'Authorization': f'Bearer {token}'})
            if r2.json().get('items'):
                print('Phase 2:', r2.json()['items'][0].get('status'))
            
            await asyncio.sleep(5)
asyncio.run(main())

