import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if 'Full' in a.get('name', '') or 'v3' in a.get('name', ''):
                print('---', a.get('name'), a.get('id'), a.get('status'))
                det = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get("id")}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
                steps = det.json().get('steps', [])
                for s in steps:
                    print(' Step:', s.get('modelStepId'), s.get('status'))
                    for o in s.get('outputParameters', []):
                        if 'MSG' in o.get('outputName', '') or 'ERROR' in o.get('outputName', ''):
                            print('  Out:', o.get('outputName'), o.get('outputValue')[:100] if isinstance(o.get('outputValue'), str) else o.get('outputValue'))
asyncio.run(main())
