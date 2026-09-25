import asyncio
import os
import json
import httpx

async def get_token():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        return json.load(f)['Default']['access-token']

async def main():
    token = await get_token()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
    
    async with httpx.AsyncClient(verify=False) as client:
        # Get Analyses
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=100', headers=headers)
        analyses = res.json().get('items', [])
        
        target_analysis = None
        for a in sorted(analyses, key=lambda x: x.get('creationTimeStamp', ''), reverse=True):
            if 'Failure Rel' in a.get('name', ''):
                target_analysis = a
                break
                
        if not target_analysis:
            print("Could not find Failure Relationships analysis.")
            return
            
        print(f"Analysis Name: {target_analysis.get('name')}")
        print(f"Analysis State: {target_analysis.get('state')}")
        
        # Get the job execution details from iotAnalysis/analyses/{id}/jobs
        job_res = await client.get(f"https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{target_analysis['id']}/jobs", headers=headers)
        jobs = job_res.json().get('items', [])
        
        if not jobs:
            print("No jobs found for this analysis.")
            return
            
        # Get the latest job
        job = jobs[0]
        compute_job_id = job.get('jobId')
        session_id = job.get('sessionId')
        
        print(f"Compute Job ID: {compute_job_id}")
        
        # Fetch the log
        headers_log = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
        log_url = f"https://iot.viya-azure-gpu.unx.sas.com/compute/sessions/{session_id}/jobs/{compute_job_id}/log"
        log_res = await client.get(log_url, headers=headers_log)
        
        if log_res.status_code == 200:
            log_items = log_res.json().get('items', [])
            errors = [item.get('line') for item in log_items if item.get('type') == 'error' or 'ERROR' in item.get('line', '').upper()]
            
            print("\n--- SAS ERROR LOGS ---")
            for e in errors:
                print(e)
                
            # If no explicit ERROR lines, print the last 50 lines to see what happened
            if not errors:
                print("\n--- LAST 50 LOG LINES ---")
                for item in log_items[-50:]:
                    print(item.get('line'))
        else:
            print(f"Failed to fetch log: {log_res.status_code} - {log_res.text}")

if __name__ == '__main__':
    asyncio.run(main())
