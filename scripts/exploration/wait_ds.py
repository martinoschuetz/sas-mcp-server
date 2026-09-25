
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        while True:
            r = await client.get('https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs?limit=10', headers={'Authorization': f'Bearer {token}'})
            jobs = r.json().get('items', [])
            running = [j for j in jobs if j.get('state') in ('running', 'pending')]
            if not running:
                print('All jobs completed.')
                break
            await asyncio.sleep(5)
asyncio.run(main())

