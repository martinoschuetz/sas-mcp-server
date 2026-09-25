
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Load simple actionset
        # Call simple.distinct on QASMartStore.PRODUCT
        payload = {
            'table': {'name': 'PRODUCT', 'caslib': 'QASMartStore'}
        }
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions/casauto/actions/simple.distinct', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json=payload)
        print(res.text)
asyncio.run(main())

