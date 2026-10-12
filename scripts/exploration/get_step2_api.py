import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
analysis_id = '0814d4c3-3335-491f-9281-9880b41768fb'
step_id = 'd14c3e9f-af03-41fa-a83a-bf354c1fe972'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

res = client.get(f'{base_url}/iotAnalysis/analyses/{analysis_id}/steps/{step_id}', headers=headers)
print(json.dumps(res.json(), indent=2))
