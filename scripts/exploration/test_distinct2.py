
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        res_sess = await client.post('https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={})
        sess_id = res_sess.json().get('session')
        payload = {'table': {'name': 'PRODUCT', 'caslib': 'QASMartStore'}}
        res = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/cas-shared-default-http/cas/sessions/{sess_id}/actions/simple.distinct', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json=payload)
        with open('distinct.json', 'w') as f:
            f.write(res.text)
asyncio.run(main())

