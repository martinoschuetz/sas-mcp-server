import os
import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
job_uri = '/jobExecution/jobs/fb2c9c0b-4637-4c72-8dc9-3f638c3a19ba' # from the step2 log links
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
res = client.get(f'{base_url}{job_uri}', headers=headers)
print(json.dumps(res.json().get('jobRequest', {}).get('arguments', {}), indent=2))
