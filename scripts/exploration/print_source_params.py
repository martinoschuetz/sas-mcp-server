import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
source_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
res = client.get(f'{base_url}/iotAnalysis/analyses/{source_id}', headers=headers)
steps = res.json().get('steps', [])

for step in steps:
    print(f"--- {step['modelStepId']} ---")
    for p in step.get('inputParameters', []):
        print(f"  {p['parameterName']}: '{p['parameterValue']}'")
