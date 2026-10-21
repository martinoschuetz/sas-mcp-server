import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
steps = res.json().get('steps', [])

step1 = next(s for s in steps if s['modelStepId'] == 'SVDD_NEW_1')
print("Step 1 Outputs:")
for p in step1.get('outputParameters', []):
    print(f"  {p['outputName']}: '{p['outputValue']}'")
