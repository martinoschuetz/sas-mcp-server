
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        det = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/ee1b0a4b-e5a0-457c-9467-12dde44fab9a', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        steps = det.json().get('steps', [])
        for s in steps:
            for o in s.get('outputParameters', []):
                print(o.get('outputName'))
asyncio.run(main())

