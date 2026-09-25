
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Phase 1
        aid1 = '03860d37-6bb8-4f73-8a60-7d4a9a19ffed'
        res1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid1}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        print('Phase 1 shortId:', res1.json().get('shortId'))
        
        # Phase 2
        aid2 = '6e093154-357d-46fa-a2f3-cf320305d6ed'
        res2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid2}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        print('Phase 2 shortId:', res2.json().get('shortId'))
asyncio.run(main())

