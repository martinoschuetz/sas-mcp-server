import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
res = client.get(f'{base_url}/iotAnalysisModels/models/SVDD', headers=headers)
steps = res.json().get('steps', [])
for s in steps:
    if s['id'] == 'SVDD_ASSET_2':
        print("SVDD_ASSET_2 has inputs:", s.get('inputs'))
        print("links:", json.dumps(s.get('links', []), indent=2))
