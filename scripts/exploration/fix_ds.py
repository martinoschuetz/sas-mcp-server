import asyncio
import json
import os
from sas_mcp_server.viya_client import make_client
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    ds_id = '32de6ace-3ea6-4c21-9079-1a8784ed0b0d'

    async with make_client(token) as client:
        resp = await client.get(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{ds_id}', headers={'Accept': 'application/vnd.sas.data.selection+json'})
        ds = resp.json()
        etag = resp.headers.get('ETag', '')
        
        ds['creationType'] = 'EIENTERPRISE'
        
        resp_put = await client.put(
            f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{ds_id}', 
            json=ds, 
            headers={'If-Match': etag, 'Content-Type': 'application/json', 'Accept': 'application/vnd.sas.data.selection+json'}
        )
        if resp_put.status_code >= 400:
            print("Error:", resp_put.text)
        else:
            print("Successfully updated to EIENTERPRISE")

if __name__ == '__main__':
    asyncio.run(main())
