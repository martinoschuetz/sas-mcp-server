import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 DS
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}'})
        ds = res.json()
        
        body = {
            'name': 'Phase 3 - Hardware Base DS 2',
            'creationType': 'DEFAULT',
            'filterCriteria': ds.get('filterCriteria', {}),
            'additionalAttributes': ds.get('additionalAttributes', [])
        }
        res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
        new_id = res2.json().get('id')
        print('Created HW ID:', new_id)
        
        cols = [
            {"columnName": "PRODUCTION_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnTableName": "PRODUCT"},
            {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_CD", "columnTableName": "PRODUCT"},
            {"columnName": "INSERVICE_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "CSTMR_STATE_CD", "columnTableName": "PRODUCT"},
            {"columnName": "CLAIMCOST", "columnTableName": "CLAIM"},
            {"columnName": "PRIM_REPL_PART_CD", "columnTableName": "CLAIM"},
            {"columnName": "EVENT_SUBMIT_DATE", "columnTableName": "CLAIM"},
            {"columnName": "REPL_PART_CD", "columnTableName": "PART"}
        ]
        
        launch_payload = {
            'launchColumnTables': ['PRODUCT', 'CLAIM', 'PART'],
            'transposeFlag': 0,
            'launchKeyDim': 'PRODUCT',
            'tableName': f"DS_{new_id.replace('-', '_')[:24]}",
            'launchAppName': 'CAS',
            'launchColumns': cols
        }
        res3 = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}, json=launch_payload)
        print('Launch Started for HW:', new_id)
asyncio.run(main())
