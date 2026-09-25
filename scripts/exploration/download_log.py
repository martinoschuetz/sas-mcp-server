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
        
        log_url = f"https://iot.viya-azure-gpu.unx.sas.com{log_uri}/content"
        res_log = await client.get(log_url, headers={'Authorization': f'Bearer {token}'})
        
        with open("full_log.txt", "w") as f:
            f.write(res_log.text)
            
if __name__ == '__main__':
    asyncio.run(main())
