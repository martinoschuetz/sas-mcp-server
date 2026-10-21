import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
        res = client.get(f'{base_url}/iotAnalysis/analysisTypes/SVDD_NEW', headers=headers)
        data = res.json()
        print(json.dumps(data, indent=2))
