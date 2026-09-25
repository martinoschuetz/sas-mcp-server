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
        res = await client.get(f"{base_url}/jobExecution/jobs?limit=4&sortBy=creationTimeStamp:descending", headers=headers)
        jobs = res.json().get('items', [])
        for job in jobs:
            err = job.get('error', {}).get('errors', [{}])[0].get('message')
            print(f"{job.get('jobRequest', {}).get('name')} ({job['id']}): {err}")
                                
if __name__ == '__main__':
    asyncio.run(main())
