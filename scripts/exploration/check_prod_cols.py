
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/tables/PRODUCT/columns?limit=1000', headers={'Authorization': f'Bearer {token}'})
        names = [c.get('name') for c in res.json().get('items', [])]
        print('CSTMR_STATE_CD in PRODUCT?', 'CSTMR_STATE_CD' in names)
        print('PLANT_CD in PRODUCT?', 'PLANT_CD' in names)
        print('MODEL_CD in PRODUCT?', 'MODEL_CD' in names)
        print('PRODUCTION_MONTH in PRODUCT?', 'PRODUCTION_MONTH' in names)
asyncio.run(main())

