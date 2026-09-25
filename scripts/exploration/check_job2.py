
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '9143258b-017a-4d7c-aded-02848832376e'
        r1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}/steps', headers={'Authorization': f'Bearer {token}'})
        if r1.json().get('items'):
            print('Phase 3:', r1.json()['items'][0].get('status'), r1.json()['items'][0].get('statusMessage'))
asyncio.run(main())

