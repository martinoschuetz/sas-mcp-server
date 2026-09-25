import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        for a in res.json().get('items', []):
            if '0075' in a.get('name', ''):
                print('Analysis:', a.get('name'), a.get('state'))
                step_res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a["id"]}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
                steps = step_res.json().get('steps', [])
                for s in steps:
                    status = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analysisActions/status?stepId={s["id"]}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis.step.summary+json'})
                    st = status.json()
                    print('  Status:', st.get('status'))
                    if st.get('status') == 'ERROR':
                        links = st.get('links', [])
                        job_id = None
                        for l in links:
                            if l.get('rel') == 'job':
                                job_id = l.get('href').split('/')[-1]
                        if job_id:
                            jres = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{job_id}', headers={'Authorization': f'Bearer {token}'})
                            print('  Job Error:', json.dumps(jres.json().get('error', {})))
asyncio.run(main())
