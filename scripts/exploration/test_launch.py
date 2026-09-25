import asyncio
import json
import os
import uuid
from sas_mcp_server.viya_client import make_client
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    new_ds_id = '32de6ace-3ea6-4c21-9079-1a8784ed0b0d'
    
    async with make_client(token) as client:
        print('Launching DS with Y...')
        resp_launch = await client.post(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launches', json={"transposeFlag": "Y"}, headers={'Accept': 'application/vnd.sas.data.selection.launch+json'})
        if resp_launch.status_code >= 400:
            print(resp_launch.text)
        else:
            print('Success with Y!')

if __name__ == '__main__':
    asyncio.run(main())
