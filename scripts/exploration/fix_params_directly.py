import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'
source_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}

res = client.get(f'{base_url}/iotAnalysis/analyses/{source_id}', headers=headers)
source = res.json()
params_to_set = {}
for s in source.get('steps', []):
    for p in s.get('inputParameters', []):
        params_to_set[p['parameterName']] = p['parameterValue']

res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
target = res.json()

for step in target.get('steps', []):
    if step['modelStepId'] in ('SVDD_NEW_2', 'SVDD_NEW_3'):
        # update params
        for p in step.get('inputParameters', []):
            if p['parameterName'] in params_to_set:
                p['parameterValue'] = params_to_set[p['parameterName']]
        
        # PUT the step directly!
        step_id = step['id']
        step_etag = step.get('version', 1) # FQA steps might not have ETag header, or they use If-Match?
        # Actually, let's try PUTting to the analysis again, but ONLY with the single step in the array (like the tool does)!
        target_copy = dict(target)
        target_copy['steps'] = [step]
        update_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json', 'Content-Type': 'application/vnd.sas.iot.analysis+json'}
        # we need If-Match from target
        res_a = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
        update_headers['If-Match'] = res_a.headers.get('ETag', '')
        
        print(f"Updating step {step['modelStepId']}...")
        put_res = client.put(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=update_headers, json=target_copy)
        print("PUT response:", put_res.status_code, put_res.text)
