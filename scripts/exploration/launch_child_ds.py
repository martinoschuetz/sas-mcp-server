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
    parent_analysis_id = '818c2846-9b4e-4a86-a9b6-4282dfdb538e'

    new_filters = [
        {'columnName': 'PRIM_REPL_PART_CD', 'component': 'CLAIM', 'operatorCode': 'IN', 'values': ['9-040']},
        {'columnName': 'MODEL_CD', 'component': 'PRODUCT', 'operatorCode': 'IN', 'values': ['Galacto']}
    ]

    async with make_client(token) as client:
        # 2. Get new DS to modify
        resp_get = await client.get(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}', headers={'Accept': 'application/vnd.sas.data.selection+json'})
        resp_get.raise_for_status()
        ds_details = resp_get.json()
        etag = resp_get.headers.get('ETag', '')

        # 3. Add filters
        filterCriteria = ds_details.get('filterCriteria', {})
        group_0 = filterCriteria.get('0', [])
        for f in new_filters:
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

        # 4. Add parent analysis link
        attrs = ds_details.get('additionalAttributes', [])
        attrs.append({'name': 'parentAnalysisId', 'value': parent_analysis_id})
        ds_details['additionalAttributes'] = attrs

        # 5. Update DS
        print('Updating DS...')
        resp_put = await client.put(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}', json=ds_details, headers={'If-Match': etag, 'Content-Type': 'application/json', 'Accept': 'application/vnd.sas.data.selection+json'})
        if resp_put.status_code >= 400:
            print(resp_put.text)
            return

        # 6. Launch DS
        print('Launching DS...')
        resp_launch = await client.post(f'{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}/launch')
        resp_launch.raise_for_status()
        print('Success!')

if __name__ == '__main__':
    asyncio.run(main())
