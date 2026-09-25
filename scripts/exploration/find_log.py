import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs?limit=20', headers={'Authorization': f'Bearer {token}'})
        for j in res.json().get('items', []):
            if j.get('state') in ['failed', 'error']:
                print('Job:', j.get('id'), j.get('name'))
                log_res = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{j["id"]}/log?limit=10000', headers={'Authorization': f'Bearer {token}'})
                if log_res.status_code == 200:
                    for item in log_res.json().get('items', []):
                        line = item.get('line', '')
                        if 'ERROR:' in line or 'Variable' in line or 'does not exist' in line:
                            print('  ', line)
asyncio.run(main())
