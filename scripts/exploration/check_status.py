
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = 'fa3d1a38-be6d-49e6-8e2e-e4dcf1fabce5'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        s = chk.json().get('status')
        print(s)
asyncio.run(main())

