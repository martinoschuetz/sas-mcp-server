import asyncio
import os
import json
import httpx

async def get_token():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

async def main():
    token = await get_token()
    headers = {
        'Authorization': f'Bearer {token}',
        'Accept': 'application/json'
    }
    base_url = "https://iot.viya-azure-gpu.unx.sas.com"
    
    async with httpx.AsyncClient(verify=False) as client:
        # Get analyses in the folder
        folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818"
        res = await client.get(f"{base_url}/iotAnalysis/analyses?filter=eq(folderID,'{folder_id}')", headers=headers)
        analyses = res.json().get('items', [])
        
        phase1_analyses = [a for a in analyses if "Phase 1 -" in a.get('name', '')]
        
        for an in phase1_analyses:
            print(f"\n=== {an['name']} (ID: {an['id']}) ===")
            # Get steps
            res_steps = await client.get(f"{base_url}/iotAnalysis/analyses/{an['id']}/steps", headers=headers)
            steps = res_steps.json().get('items', [])
            for step in steps:
                step_id = step['id']
                print(f"Step ID: {step_id}")
                
                # Get status
                res_status = await client.get(f"{base_url}/iotAnalysis/analysisActions/status?stepId={step_id}", headers=headers)
                status_data = res_status.json()
                print("Status:", status_data.get('status'))
                
                # If there's a job, get the log
                job = status_data.get('job', {})
                if job:
                    job_links = job.get('links', [])
                    job_uri = next((link['uri'] for link in job_links if link['rel'] == 'job'), None)
                    if job_uri:
                        # Get job details to find log
                        res_job = await client.get(f"{base_url}{job_uri}", headers=headers)
                        if res_job.status_code == 200:
                            job_data = res_job.json()
                            if 'logLocation' in job_data:
                                log_uri = job_data['logLocation']
                                res_log = await client.get(f"{base_url}{log_uri}", headers=headers)
                                if res_log.status_code == 200:
                                    log_items = res_log.json().get('items', [])
                                    # Print last 10 lines of log
                                    for item in log_items[-15:]:
                                        if item.get('type') in ['NOTE', 'ERROR', 'WARNING']:
                                            print(f"{item.get('type')}: {item.get('line')}")
                            else:
                                print("No logLocation found in job.")

if __name__ == '__main__':
    asyncio.run(main())
