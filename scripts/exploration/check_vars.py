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
    url = 'https://iot.viya-azure-gpu.unx.sas.com/fqa/dataModelVariables?limit=1000'
    
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get(url, headers=headers)
        items = res.json().get('items', [])
        print(f"Total FQA Variables: {len(items)}")
        
        for i in items:
            name = i.get('columnName', '').upper()
            if any(x in name for x in ['CLAIM', 'LABOR', 'EVENT', 'STATE', 'PART', 'MONTH', 'PROVINCE']):
                print(f"{i.get('columnTableName')}.{name}  ({i.get('columnNameLabel')})")

if __name__ == '__main__':
    asyncio.run(main())
