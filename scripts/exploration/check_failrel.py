
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        det = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/35b99987-1212-440b-8abc-935d09c4dc88', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        steps = det.json().get('steps', [])
        for s in steps:
            print(' Step:', s.get('modelStepId'), s.get('status'))
            outputs = s.get('outputParameters', [])
            for o in outputs:
                if 'ERROR' in o.get('outputName', '') or 'MSG' in o.get('outputName', ''):
                    print('  Msg:', o.get('outputName'), o.get('outputValue'))
asyncio.run(main())

