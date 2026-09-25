
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        r = await client.get('https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/3d27e564-e12b-4844-b996-54ef316400f3', headers={'Authorization': f'Bearer {token}'})
        print(r.json().get('state'))
asyncio.run(main())

