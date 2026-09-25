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
    
    parent_ds_id = '21a65a93-8c37-4969-99b0-82ca2a260c2d'
    new_name = 'Alert 1 Galacto 9-040 Triage V2'

    async with make_client(token) as client:
        # Try copying with creationType override
        body = {
            "name": new_name,
            "creationType": "EIENTERPRISE"
        }
        
        resp_copy = await client.post(
            f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_ds_id}/copy', 
            json=body, 
            headers={'Accept': 'application/vnd.sas.data.selection+json'}
        )
        resp_copy.raise_for_status()
        new_ds = resp_copy.json()
        print(f"Created copy ID: {new_ds['id']}")
        print(f"CreationType immediately after copy: {new_ds.get('creationType')}")

if __name__ == '__main__':
    asyncio.run(main())
