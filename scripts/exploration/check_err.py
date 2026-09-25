
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/35b99987-1212-440b-8abc-935d09c4dc88', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        steps = res.json().get('steps', [])
        for s in steps:
            print(' Step:', s.get('modelStepId'), s.get('status'))
            for o in s.get('outputParameters', []):
                print('  Out:', o.get('outputName'), o.get('outputValue')[:100] if isinstance(o.get('outputValue'), str) else o.get('outputValue'))
asyncio.run(main())

