import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
res = client.get(f'{base_url}/iotAnalysisModels/models/SVDD/steps/SVDD_ASSET_2', headers=headers)
print(json.dumps(res.json().get('inputs', []), indent=2))
