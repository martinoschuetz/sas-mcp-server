import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '<REDACTED-USE-VIYA_PASSWORD-ENV-VAR>'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
steps = res.json().get('steps', [])
step2 = next(s for s in steps if s['modelStepId'] == 'SVDD_NEW_2')

jobs_link = next(l for l in step2['links'] if l['rel'] == 'job')
job_uri = jobs_link['uri']

headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
res = client.get(f'{base_url}{job_uri}', headers=headers)
job = res.json()

log_link = next(l for l in job['links'] if l['rel'] == 'log')
res = client.get(f'{base_url}{log_link["uri"]}', headers=headers)
log_file = res.json()
content_link = next(l for l in log_file['links'] if l['rel'] == 'content')

res = client.get(f'{base_url}{content_link["uri"]}', headers={'Authorization': f'Bearer {token}'})
with open('scripts/exploration/step2_log_v2.txt', 'w') as f:
    f.write(res.text)
