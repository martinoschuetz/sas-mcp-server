import httpx
import json
import time

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'
source_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'
client = httpx.Client(verify=False)

# 1. Login
res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}

# 2. Extract Source params
res = client.get(f'{base_url}/iotAnalysis/analyses/{source_id}', headers=headers)
source = res.json()
params_to_set = {}
for s in source.get('steps', []):
    for p in s.get('inputParameters', []):
        params_to_set[p['parameterName']] = p['parameterValue']

# 3. Update Target params
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
target = res.json()
etag = res.headers.get('ETag', '')
for s in target.get('steps', []):
    for p in s.get('inputParameters', []):
        pname = p['parameterName']
        if pname in params_to_set:
            p['parameterValue'] = params_to_set[pname]

update_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}
res = client.put(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=update_headers, json=target)
if res.status_code == 200:
    print("Successfully updated target params")
else:
    print("Failed to update target:", res.text)
    exit(1)

# 4. Trigger Step 2
target = res.json()
step2 = next(s for s in target['steps'] if s['modelStepId'] == 'SVDD_NEW_2')
step_id = step2['id']

run_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
print(f"Triggering Step 2 ({step_id})...")
try:
    run_res = client.post(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}/jobs', headers=run_headers, json={})
    print("Run response:", run_res.status_code)
except httpx.ReadTimeout:
    print("Timeout triggering Step 2. It is probably running.")

# 5. Wait for Step 2
print("Polling Step 2 status...")
while True:
    res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
    step2_current = next(s for s in res.json()['steps'] if s['id'] == step_id)
    status = step2_current.get('status', '').upper()
    print("Step 2 status:", status)
    if status in ('COMPLETED', 'ERROR', 'FAILED'):
        break
    time.sleep(10)
    
if status == 'COMPLETED':
    # 6. Trigger Step 3
    print("Step 2 complete! Triggering Step 3...")
    step3 = next(s for s in res.json()['steps'] if s['modelStepId'] == 'SVDD_NEW_3')
    step3_id = step3['id']
    try:
        run_res = client.post(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step3_id}/jobs', headers=run_headers, json={})
        print("Run response:", run_res.status_code)
    except httpx.ReadTimeout:
        print("Timeout triggering Step 3.")
        
    print("Polling Step 3 status...")
    while True:
        res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
        step3_current = next(s for s in res.json()['steps'] if s['id'] == step3_id)
        status3 = step3_current.get('status', '').upper()
        print("Step 3 status:", status3)
        if status3 in ('COMPLETED', 'ERROR', 'FAILED'):
            break
        time.sleep(10)
