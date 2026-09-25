import asyncio
import json
import os
import httpx
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    ds_id = 'b09ba15a-d4df-46c0-abf6-dcb9df7300bb' # DS test 5
    an_id = '97a1ac7c-0871-497a-a25d-5042f84a10a8' # EI test 5
    
    async with httpx.AsyncClient(verify=False) as client:
        # Get parent analysis to copy its columns for launching DS properly
        cols = [
            {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
            {"columnName": "MODEL_CD", "columnNameLabel": "Model Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"}
        ]
        launch_body = {
            "tableName": f"DS_{ds_id.replace('-', '_')[:24]}",
            "launchAppName": "CAS",
            "transposeFlag": 0,
            "launchKeyDim": "PRODUCT",
            "launchColumnTables": ["CLAIM", "PRODUCT"],
            "launchColumns": cols
        }
        resp_launch = await client.post(
            f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{ds_id}/launches",
            json=launch_body,
            headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection.launch+json', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}
        )
        print("Launch status:", resp_launch.status_code)
        if resp_launch.status_code >= 400:
            print(resp_launch.text)
        
        await asyncio.sleep(5)
        
        # Check Analysis status
        resp_f = await client.get(
            f"{VIYA_ENDPOINT}/iotAnalysis/analyses?filter=eq(name,'EI test 5')",
            headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
        )
        items = resp_f.json().get('items', [])
        if items:
            an = items[0]
            print("Status in list:", an.get("status"), an.get("displayStatus"), "lastRunDate:", an.get("lastRunDate"))

if __name__ == '__main__':
    asyncio.run(main())
