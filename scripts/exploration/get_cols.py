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
    url = 'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/21a65a93-8c37-4969-99b0-82ca2a260c2d/launches/70f0aab8-a5ba-47df-9e08-e839b01986cb'
    
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get(url, headers=headers)
        cols = res.json().get('launchColumns', [])
        for c in cols:
            print(f"{c['columnTableName']}.{c['columnName']}")

if __name__ == '__main__':
    asyncio.run(main())
