
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/5767ab0b-62b1-4bce-997f-10372f727813/launches', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
        print(res.text)
asyncio.run(main())

