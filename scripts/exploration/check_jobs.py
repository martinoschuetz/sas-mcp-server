import asyncio
import os
import json
import httpx

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Accept': 'application/json'
    }
    base_url = "https://iot.viya-azure-gpu.unx.sas.com"
    
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get(f"{base_url}/jobExecution/jobs?limit=5&sortBy=creationTimeStamp:descending", headers=headers)
        jobs = res.json().get('items', [])
        for job in jobs:
            print(f"\n--- Job {job['id']} - State: {job.get('state')} ---")
            if job.get('state') == 'failed':
                log_uri = job.get('logLocation')
                if log_uri:
                    res_log = await client.get(f"{base_url}{log_uri}", headers=headers)
                    log_items = res_log.json().get('items', [])
                    for i in log_items[-20:]:
                        print(f"[{i.get('type')}] {i.get('line')}")
                                
if __name__ == '__main__':
    asyncio.run(main())
