import asyncio
import os
import json
import httpx

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
    job_id = '747c3b1f-12e6-43ee-8b72-58fcec922772'
    url = f'https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{job_id}'
    
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get(url, headers=headers)
        log_uri = res.json().get('logLocation')
        
        res_log = await client.get(f"https://iot.viya-azure-gpu.unx.sas.com{log_uri}", headers=headers)
        lines = res_log.json().get('items', [])
        
        for item in lines[-150:]:
            print(item.get('line', ''))

if __name__ == '__main__':
    asyncio.run(main())
