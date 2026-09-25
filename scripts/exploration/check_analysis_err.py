
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '9143258b-017a-4d7c-aded-02848832376e'
        r1 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}'})
        print(r1.json().get('status'), r1.json().get('statusMessage'))
asyncio.run(main())

