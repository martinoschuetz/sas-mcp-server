import os
import httpx
import json
import time
import sys

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
source_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'

client = httpx.Client(verify=False, timeout=60.0)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')

if not token:
    print("Login failed")
    sys.exit(1)

headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}

# 1. Get Source parameters
print("Fetching source parameters...")
res = client.get(f'{base_url}/iotAnalysis/analyses/{source_id}', headers=headers)
source_analysis = res.json()

params_to_set = {}
for step in source_analysis.get('steps', []):
    for param in step.get('inputParameters', []):
        params_to_set[param['parameterName']] = param['parameterValue']

# 2. Update Target parameters
print("Updating target parameters...")
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
target_analysis = res.json()
etag = res.headers.get('ETag', '')

for step in target_analysis.get('steps', []):
    for param in step.get('inputParameters', []):
        pname = param.get('parameterName')
        if pname in params_to_set:
            param['parameterValue'] = params_to_set[pname]

update_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}
res = client.put(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=update_headers, json=target_analysis)
if res.status_code != 200:
    print("Failed to update target analysis:", res.status_code, res.text)
    sys.exit(1)

print("Target parameters updated successfully.")

# Refresh target analysis to get latest step IDs and statuses
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
target_analysis = res.json()
steps = target_analysis.get('steps', [])

run_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
job_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

def wait_for_job(job_id):
    while True:
        try:
            j_res = client.get(f'{base_url}/jobExecution/jobs/{job_id}', headers=job_headers)
            if j_res.status_code == 200:
                state = j_res.json().get('state', '').lower()
                if state in ('completed', 'failed', 'canceled'):
                    return state
            time.sleep(5)
        except Exception as e:
            print("Poll error:", e)
            time.sleep(5)

for i, step in enumerate(steps):
    step_id = step['id']
    step_name = step.get('modelStepId', f'Step {i+1}')
    print(f"--- Running {step_name} ---")
    
    try:
        run_res = client.post(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}/jobs', headers=run_headers, json={})
        if run_res.status_code not in (200, 201, 202):
            print(f"Failed to start {step_name}:", run_res.status_code, run_res.text)
            break
            
        job_id = run_res.json().get('jobId') or run_res.json().get('id')
        print(f"{step_name} job submitted: {job_id}. Waiting for completion...")
        
        state = wait_for_job(job_id)
        print(f"{step_name} finished with state: {state}")
        
        if state != 'completed':
            print(f"Stopping sequence because {step_name} ended in {state}.")
            break
    except httpx.ReadTimeout:
        print(f"Timeout triggering {step_name}. Polling step status from analysis...")
        # Since we missed the job ID, we poll the analysis step status directly
        while True:
            a_res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
            a_data = a_res.json()
            current_step = next(s for s in a_data['steps'] if s['id'] == step_id)
            status = current_step.get('status', '').upper()
            if status in ('COMPLETED', 'ERROR', 'CANCELED', 'FAILED'):
                print(f"{step_name} finished with status: {status}")
                state = 'completed' if status == 'COMPLETED' else 'failed'
                break
            time.sleep(5)
        
        if state != 'completed':
            print(f"Stopping sequence because {step_name} ended in {state}.")
            break

print("Sequence execution script finished.")
