
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        det = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/30a09229-b2dc-4d07-8d82-473a3dd39edc', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        steps = det.json().get('steps', [])
        for s in steps:
            print(' Step:', s.get('modelStepId'), s.get('status'))
            for o in s.get('outputParameters', []):
                if 'ERROR' in o.get('outputName') or 'MSG' in o.get('outputName') or 'TABLENAME' in o.get('outputName'):
                    print('  Out:', o.get('outputName'), o.get('outputValue')[:100] if isinstance(o.get('outputValue'), str) else o.get('outputValue'))
asyncio.run(main())

