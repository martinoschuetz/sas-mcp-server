import asyncio
import json
import os
import uuid
import httpx
from sas_mcp_server.viya_client import make_client
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    refresh_token = auth['Default']['refresh-token']
    
    # 1. Refresh Token
    async with httpx.AsyncClient(verify=False) as client:
        resp = await client.post(
            f"{VIYA_ENDPOINT}/SASLogon/oauth/token",
            data={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": "vscode"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        if resp.status_code >= 400:
            print("Failed to refresh token:", resp.text)
            return
            
        token_data = resp.json()
        new_access_token = token_data["access_token"]
        new_refresh_token = token_data.get("refresh_token", refresh_token)
        
        # Save back to file so we don't desync
        auth['Default']['access-token'] = new_access_token
        auth['Default']['refresh-token'] = new_refresh_token
        with open(auth_file, 'w') as f:
            json.dump(auth, f)
            
    print("Token refreshed!")
    token = new_access_token
    
    # Inputs
    alert1_filters = [
        {'columnName': 'PRIM_REPL_PART_CD', 'component': 'CLAIM', 'operatorCode': 'IN', 'values': ['9-040']},
        {'columnName': 'MODEL_CD', 'component': 'PRODUCT', 'operatorCode': 'IN', 'values': ['Galacto']}
    ]
    parent_analysis_id = '818c2846-9b4e-4a86-a9b6-4282dfdb538e'
    parent_ds_id = '21a65a93-8c37-4969-99b0-82ca2a260c2d'
    
    ds_name = "DS test 5"
    an_name = "EI test 5"
    folder_id = "79eaaedd-2f6b-413f-8621-52b09325c818"

    async with make_client(token) as client:
        # 2. Copy DS to create DS test 2 (with EIENTERPRISE)
        body = {
            "name": ds_name,
            "creationType": "EIENTERPRISE"
        }
        resp_copy = await client.post(
            f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{parent_ds_id}/copy', 
            json=body, 
            headers={'Accept': 'application/vnd.sas.data.selection+json'}
        )
        resp_copy.raise_for_status()
        new_ds_id = resp_copy.json()['id']
        
        # 3. Update filters for Alert 1
        resp_get = await client.get(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}', headers={'Accept': 'application/vnd.sas.data.selection+json'})
        ds_details = resp_get.json()
        etag = resp_get.headers.get('ETag', '')
        
        filterCriteria = ds_details.get('filterCriteria', {})
        group_0 = filterCriteria.get('0', [])
        for f in alert1_filters:
            group_0.append({
                'id': str(uuid.uuid4()),
                'criteriaGroupId': new_ds_id,
                'columnName': f['columnName'],
                'operatorCode': f['operatorCode'],
                'excludeFlag': False,
                'componentTypeCode': f['component'],
                'component': f['component'],
                'filterAttributeId': f"{f['columnName']}_{f['component']}",
                'groupId': '0',
                'uiDisplay': False,
                'values': f['values']
            })
        ds_details['filterCriteria'] = {'0': group_0}
        
        attrs = ds_details.get('additionalAttributes', [])
        attrs.append({'name': 'parentAnalysisId', 'value': parent_analysis_id})
        ds_details['additionalAttributes'] = attrs
        
        resp_put = await client.put(
            f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}', 
            json=ds_details, 
            headers={'If-Match': etag, 'Content-Type': 'application/json', 'Accept': 'application/vnd.sas.data.selection+json'}
        )
        resp_put.raise_for_status()
        print(f"Created DS: {new_ds_id}")
        
        # 4. Create Analysis object
        an_body = {
            "name": an_name,
            "modelName": "EIENTERPRISE_PRODUCT",
            "dataSelectionId": new_ds_id,
            "folderID": folder_id
        }
        collection_body = {
            "name": "analysis",
            "items": [an_body]
        }
        resp_an = await client.post(
            f'{VIYA_ENDPOINT}/iotAnalysis/analyses', 
            json=collection_body, 
            headers={'Accept': 'application/json', 'Content-Type': 'application/json'}
        )
        if resp_an.status_code >= 400:
            print("Failed to create Analysis:", resp_an.text)
        else:
            analysis_id = resp_an.json()['items'][0]['id']
            print(f"Created Analysis: {analysis_id}")
            
            # Try starting it
            try:
                resp_run = await client.post(
                    f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}/jobs",
                    json={},
                    headers={"Accept": "application/vnd.sas.iot.analysis.job+json"}
                )
                if resp_run.status_code == 404:
                    print("Fallback: getting step ID...")
                    resp_full = await client.get(
                        f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}",
                        headers={"Accept": "application/vnd.sas.iot.analysis+json"}
                    )
                    steps = resp_full.json().get("steps", [])
                    step_id = steps[0]["id"]
                    resp_run = await client.post(
                        f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}/steps/{step_id}/jobs",
                        json={},
                        headers={"Accept": "application/json"}
                    )
                resp_run.raise_for_status()
                print("Successfully started job for Analysis!")
            except Exception as e:
                print("Failed to start job:", e)

if __name__ == '__main__':
    asyncio.run(main())
