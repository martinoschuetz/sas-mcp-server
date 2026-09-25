import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 DS
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}'})
        ds = res.json()
        
        async def create_ds(name, tables, cols):
            body = {
                'name': name,
                'creationType': 'DEFAULT',
                'filterCriteria': ds.get('filterCriteria', {}),
                'additionalAttributes': ds.get('additionalAttributes', [])
            }
            res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
            if res2.status_code != 201:
                print('Failed to create DS:', res2.text)
                return None
            new_id = res2.json().get('id')
            print(f'Created {name} with ID: {new_id}')
            
            launch_payload = {
                'launchColumnTables': tables,
                'transposeFlag': 0,
                'launchKeyDim': 'PRODUCT',
                'tableName': f"DS_{new_id.replace('-', '_')[:24]}",
                'launchAppName': 'CAS',
                'launchColumns': cols
            }
            res3 = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}, json=launch_payload)
            if res3.status_code != 201:
                print('Launch Failed:', res3.text)
                return None
            print(f'Launch Started for {new_id}')
            return new_id
                
        cols_labor = [
            {"columnName": "PRODUCTION_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnTableName": "PRODUCT"},
            {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_CD", "columnTableName": "PRODUCT"},
            {"columnName": "INSERVICE_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "CSTMR_STATE_CD", "columnTableName": "PRODUCT"},
            {"columnName": "CLAIMCOST", "columnTableName": "CLAIM"},
            {"columnName": "PRIM_LABOR_CD", "columnTableName": "CLAIM"},
            {"columnName": "EVENT_SUBMIT_DATE", "columnTableName": "CLAIM"},
            {"columnName": "LABOR_CD", "columnTableName": "LABOR"},
            {"columnName": "LABOR_AMOUNT", "columnTableName": "LABOR"}
        ]
        
        cols_part = [
            {"columnName": "PRODUCTION_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnTableName": "PRODUCT"},
            {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_CD", "columnTableName": "PRODUCT"},
            {"columnName": "INSERVICE_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "CSTMR_STATE_CD", "columnTableName": "PRODUCT"},
            {"columnName": "CLAIMCOST", "columnTableName": "CLAIM"},
            {"columnName": "PRIM_REPL_PART_CD", "columnTableName": "CLAIM"},
            {"columnName": "EVENT_SUBMIT_DATE", "columnTableName": "CLAIM"},
            {"columnName": "REPL_PART_CD", "columnTableName": "PART"},
            {"columnName": "REPL_PART_AMT", "columnTableName": "PART"}
        ]
        
        id_labor = await create_ds('Phase 3 - Workmanship Base DS 3', ['PRODUCT', 'CLAIM', 'LABOR'], cols_labor)
        id_part = await create_ds('Phase 3 - Hardware Base DS 3', ['PRODUCT', 'CLAIM', 'PART'], cols_part)
        
        print(f'{id_labor},{id_part}')
asyncio.run(main())
