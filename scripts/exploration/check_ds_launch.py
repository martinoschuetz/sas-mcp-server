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
        ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        url = f"{base_url}/dataSelection/dataSelections/{ds_id}/launches"
        res = await client.get(url, headers=headers)
        launches = res.json().get('items', [])
        for i, l in enumerate(launches):
            print(f"Launch {i} ID: {l.get('id')} State: {l.get('state')}")
            job_url = f"{base_url}/jobExecution/jobs/{l['id']}"
            job_res = await client.get(job_url, headers=headers)
            err = job_res.json().get('error')
            if err:
                print("  Error:", err)
                                
if __name__ == '__main__':
    asyncio.run(main())
