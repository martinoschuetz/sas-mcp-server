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
    token = auth['Default']['access-token']
    
    # Inputs
    combined_filters = [
        {'columnName': 'PRIM_REPL_PART_CD', 'component': 'CLAIM', 'operatorCode': 'IN', 'values': ['9-040', '1-001']},
        {'columnName': 'MODEL_CD', 'component': 'PRODUCT', 'operatorCode': 'IN', 'values': ['Galacto']}
    ]
    parent_analysis_id = '818c2846-9b4e-4a86-a9b6-4282dfdb538e'
    parent_ds_id = '21a65a93-8c37-4969-99b0-82ca2a260c2d'
    
    ds_name = "Alert 1 and 2 Combined Galacto DS"

    async with make_client(token) as client:
        # 1. Copy Parent DS
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
        
        # 2. Update filters for combined alert
        resp_get = await client.get(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}', headers={'Accept': 'application/vnd.sas.data.selection+json'})
        ds_details = resp_get.json()
        etag = resp_get.headers.get('ETag', '')
        
        filterCriteria = ds_details.get('filterCriteria', {})
        group_0 = filterCriteria.get('0', [])
        for f in combined_filters:
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
        print(f"Created Combined DS: {new_ds_id} '{ds_name}'")

if __name__ == '__main__':
    asyncio.run(main())
