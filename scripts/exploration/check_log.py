import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        aid = None
        for a in res.json().get('items', []):
            if a.get('dataSelectionId') == '2d0999cd-be5e-4477-88fd-c04dce9aa326' and 'Exposure' in a.get('name'):
                aid = a.get('id')
                break
        
        step_res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        steps = step_res.json().get('steps', [])
        s = steps[0]
        status = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analysisActions/status?stepId=' + s['id'], headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis.step.summary+json'})
        st = status.json()
        job_id = None
        for l in st.get('links', []):
            if l.get('rel') == 'job':
                job_id = l.get('href').split('/')[-1]
                
        log_res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{job_id}/log?limit=10000', headers={'Authorization': f'Bearer {token}'})
        print('Log:', json.dumps(log_res.json(), indent=2))
asyncio.run(main())
