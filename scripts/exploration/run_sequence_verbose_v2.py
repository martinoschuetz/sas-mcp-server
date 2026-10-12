import httpx
import json
import time
import sys
import datetime

def log(msg):
    print(f"[{datetime.datetime.now().isoformat()}] {msg}")
    sys.stdout.flush()

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
target_id = '0814d4c3-3335-491f-9281-9880b41768fb'

client = httpx.Client(verify=False, timeout=120.0)

log("Logging in...")
res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '<REDACTED-USE-VIYA_PASSWORD-ENV-VAR>'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')

if not token:
    log("Login failed")
    sys.exit(1)

headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
run_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
job_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

log("Fetching target analysis...")
res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
target_analysis = res.json()
steps = target_analysis.get('steps', [])

for i, step in enumerate(steps):
    step_id = step['id']
    step_name = step.get('modelStepId', f'Step {i+1}')
    
    # Refresh analysis to get latest step status
    a_res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
    current_step = next(s for s in a_res.json()['steps'] if s['id'] == step_id)
    status = current_step.get('status', '').upper()
    log(f"--- {step_name} is currently {status} ---")
    
    if status == 'COMPLETED':
        log(f"{step_name} is already COMPLETED. Skipping run.")
        continue
    
    if status in ('ERROR', 'FAILED'):
        log(f"{step_name} is in {status} state. Need to stop sequence.")
        sys.exit(1)

    if status != 'RUNNING':
        log(f"Triggering {step_name}...")
        try:
            run_res = client.post(f'{base_url}/iotAnalysis/analyses/{target_id}/steps/{step_id}/jobs', headers=run_headers, json={})
            if run_res.status_code not in (200, 201, 202):
                log(f"Failed to start {step_name}: {run_res.status_code} {run_res.text}")
                break
            
            job_id = run_res.json().get('jobId') or run_res.json().get('id')
            log(f"{step_name} job submitted: {job_id}. Waiting for completion...")
        except httpx.ReadTimeout:
            log(f"Timeout triggering {step_name}. Will poll analysis status anyway.")
            job_id = None
    else:
        log(f"{step_name} is currently RUNNING. Will wait for completion.")
        job_id = None

    # Poll status
    state = 'unknown'
    while True:
        a_res = client.get(f'{base_url}/iotAnalysis/analyses/{target_id}', headers=headers)
        current_step = next(s for s in a_res.json()['steps'] if s['id'] == step_id)
        current_status = current_step.get('status', '').upper()
        log(f"Polled step status: {current_status}")
        
        if current_status in ('COMPLETED', 'ERROR', 'CANCELED', 'FAILED'):
            state = 'completed' if current_status == 'COMPLETED' else 'failed'
            break
            
        time.sleep(10)
        
    if state != 'completed':
        log(f"Stopping sequence because {step_name} ended in {state}.")
        sys.exit(1)

log("Sequence execution script finished.")
