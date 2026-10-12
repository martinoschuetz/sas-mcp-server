import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
analysis_id = '0814d4c3-3335-491f-9281-9880b41768fb'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
        res = client.get(f'{base_url}/iotAnalysis/analyses/{analysis_id}', headers=headers)
        data = res.json()
        print(f"Overall status: {data.get('status')}")
        for i, step in enumerate(data.get('steps', [])):
            print(f"Step {i+1} status: {step.get('status')} - {step.get('modelStepId')}")
