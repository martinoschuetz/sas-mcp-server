import asyncio
import json
import os
import httpx
from datetime import datetime
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    async with httpx.AsyncClient(verify=False) as client:
        parent_analysis_id = '818c2846-9b4e-4a86-a9b6-4282dfdb538e'
        ds_id = '3532b0ad-4544-49a4-8ebe-0a87aa1b0a72'
        folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
        
        copy_url = f"{VIYA_ENDPOINT}/iotAnalysis/analysisActions/copies"
        payload = {
            "version": 1,
            "resources": [parent_analysis_id]
        }
        resp = await client.post(
            copy_url, 
            json=payload, 
            headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
        )
        print("COPY POST:", resp.status_code)
        if resp.status_code < 400:
            print("COPY RESPONSE:", resp.json())
            an_id = resp.json()[0]["id"] if isinstance(resp.json(), list) else resp.json().get("items", [{}])[0].get("id")
            
            # Link to the DS
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{an_id}",
                headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
            )
            new_analysis = resp_get.json()
            new_analysis["name"] = "EI test 8"
            new_analysis["dataSelectionId"] = ds_id
            new_analysis["folderID"] = folder_id
            etag = resp_get.headers.get("ETag", "")
            
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{an_id}",
                headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json', 'Content-Type': 'application/json', 'If-Match': etag},
                json=new_analysis
            )
            print("PUT:", resp_put.status_code)
            
            resp_f = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses?filter=eq(name,'EI test 8')",
                headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
            )
            items = resp_f.json().get('items', [])
            if items:
                an = items[0]
                print("Status in list:", an.get("status"), an.get("displayStatus"))
            else:
                print("Not found in list")

if __name__ == '__main__':
    asyncio.run(main())
