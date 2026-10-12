import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'
step_id = 'd14c3e9f-af03-41fa-a83a-bf354c1fe972'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

# Let's get the step 
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}', headers=headers)
step = res.json()
params = step.get('inputParameters', [])

# Let's PUT it directly to /inputParameters
put_url = f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}/inputParameters'
put_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
res2 = client.put(put_url, headers=put_headers, json=params)
print("PUT inputParameters:", res2.status_code, res2.text)

# Let's also check if there is an endpoint like PUT /iotAnalysis/analyses/{id}/steps/{stepId}
res3 = client.put(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}', headers=put_headers, json=step)
print("PUT step:", res3.status_code, res3.text)

