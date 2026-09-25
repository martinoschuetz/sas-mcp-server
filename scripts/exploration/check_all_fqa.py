
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/tables/columns?limit=10000', headers={'Authorization': f'Bearer {token}'})
        
        with open('fqa_vars.md', 'w') as f:
            f.write('# FQA Available Variables\n\n')
            for c in res.json().get('items', []):
                table = c.get('tableId')
                col = c.get('name')
                label = c.get('label')
                type_ = c.get('type')
                f.write(f'- {table}.{col} ({type_}): {label}\n')
asyncio.run(main())

