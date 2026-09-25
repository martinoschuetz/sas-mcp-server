
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '6a016c3c-e353-4cba-87cd-6f8278a76604'
        r1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}/steps', headers={'Authorization': f'Bearer {token}'})
        if r1.json().get('items'):
            print('Phase 2:', r1.json()['items'][0].get('status'), r1.json()['items'][0].get('statusMessage'))
asyncio.run(main())

