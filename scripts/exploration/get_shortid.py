
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = '9143258b-017a-4d7c-aded-02848832376e'
        res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        print(res.json().get('shortId'))
asyncio.run(main())

