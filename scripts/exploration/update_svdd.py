import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
analysis_id = '21db64e2-c461-4ea2-b508-bece04182500'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
        res = client.get(f'{base_url}/iotAnalysis/analyses/{analysis_id}', headers=headers)
        analysis = res.json()
        step_id = analysis['steps'][0]['id']

        run_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
        res_run = client.post(f'{base_url}/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs', headers=run_headers, json={})
        print("Run status:", res_run.status_code)
        
        job_id = res_run.json().get('jobId') or res_run.json().get('id')
        print(f"Job ID: {job_id}")
