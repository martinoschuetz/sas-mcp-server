import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 DS
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}'})
        ds = res.json()
        
        # Create new DS
        body = {
            'name': 'Alert 2 Analysis Base DS 7',
            'creationType': 'DEFAULT',
            'filterCriteria': ds.get('filterCriteria', {}),
            'additionalAttributes': ds.get('additionalAttributes', [])
        }
        
        res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
        print('Status:', res2.status_code)
        if res2.status_code == 201:
            new_id = res2.json().get('id')
            print('New DS:', new_id)
            
            cols = [
                {"columnName": "PRODUCTION_DATE", "columnNameLabel": "Production Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnNameLabel": "Selling Dealer Country", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "MODEL_CD", "columnNameLabel": "Model Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "SELLING_DEALER_CD", "columnNameLabel": "Selling Dealer Code", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "INSERVICE_DATE", "columnNameLabel": "In Service Date", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "CSTMR_STATE_CD", "columnNameLabel": "Customer State", "columnTableName": "PRODUCT", "columnTableNameLabel": "Products"},
                {"columnName": "PRIM_REPL_PART_CD", "columnNameLabel": "Primary Part Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "CLAIMCOST", "columnNameLabel": "Total Claim Cost", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "PRIM_LABOR_CD", "columnNameLabel": "Primary Labor Code", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "EVENT_SUBMIT_DATE", "columnNameLabel": "Claim Submit Date", "columnTableName": "CLAIM", "columnTableNameLabel": "Claims"},
                {"columnName": "REPL_PART_CD", "columnNameLabel": "Replaced Part Code", "columnTableName": "PART", "columnTableNameLabel": "Parts"}
            ]
            
            launch_payload = {
                'launchColumnTables': ['PRODUCT', 'CLAIM', 'LABOR', 'PART'], 
                'transposeFlag': 0, 
                'launchKeyDim': 'PRODUCT',
                'tableName': f"DS_{new_id.replace('-', '_')[:24]}",
                'launchAppName': 'CAS',
                'launchColumns': cols
            }
            res3 = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}, json=launch_payload)
            print('Launch Status:', res3.status_code)
            if res3.status_code != 201:
                print(res3.text)
            else:
                print('Success! Ready to run analyses on:', new_id)
                # Wait for launch to finish by writing the id to a file
                with open('ready_ds_id.txt', 'w') as f:
                    f.write(new_id)
asyncio.run(main())
