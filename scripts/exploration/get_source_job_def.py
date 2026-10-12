import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
# We need to find the job ID for the source analysis Step 2
source_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '<REDACTED-USE-VIYA_PASSWORD-ENV-VAR>'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
res = client.get(f'{base_url}/iotAnalysis/analyses/{source_id}', headers=headers)
step2 = next(s for s in res.json()['steps'] if s['modelStepId'] == 'SVDD_ASSET_2')
jobs_link = next(l for l in step2['links'] if l['rel'] == 'job')
job_uri = jobs_link['uri']

res = client.get(f'{base_url}{job_uri}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
job_req = res.json().get('jobRequest', {})
print("Arguments:", json.dumps(job_req.get('arguments', {}), indent=2))
