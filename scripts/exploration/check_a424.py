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
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=100', headers=headers)
        analyses = res.json().get('items', [])
        
        target_analysis = None
        for a in analyses:
            if 'Failure Rel' in a.get('name', '') and 'a424' in a.get('name', ''):
                target_analysis = a
                break
                
        if not target_analysis:
            print("Could not find analysis.")
            return
            
        print(f"Analysis Name: {target_analysis.get('name')}")
        print(f"Analysis State: {target_analysis.get('state')}")
        
        job_res = await client.get(f"https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{target_analysis['id']}/jobs", headers=headers)
        jobs = job_res.json().get('items', [])
        
        if not jobs:
            print("No jobs found for this analysis.")
            
            # Since no jobs found on /iotAnalysis/analyses/{id}/jobs, let's search via /compute/sessions or we know it failed locally
            # Wait, if "No jobs found", it means the job didn't even start on Viya or the MCP script failed to submit it!
            # But the task log said "Job completed: error" ? Let's verify task-17302.log!
            return
            
        job = jobs[0]
        compute_job_id = job.get('jobId')
        session_id = job.get('sessionId')
        
        log_url = f"https://iot.viya-azure-gpu.unx.sas.com/compute/sessions/{session_id}/jobs/{compute_job_id}/log"
        log_res = await client.get(log_url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
        
        if log_res.status_code == 200:
            log_items = log_res.json().get('items', [])
            errors = [item.get('line') for item in log_items if item.get('type') == 'error' or 'ERROR' in item.get('line', '').upper()]
            print('\n--- SAS ERROR LOGS ---')
            for e in errors:
                print(e)
            if not errors:
                print('\n--- LAST 50 LOG LINES ---')
                for item in log_items[-50:]:
                    print(item.get('line'))

if __name__ == '__main__':
    asyncio.run(main())
