import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Launch it with LABOR and metrics AND PRODUCT_ID
        new_id = '61631588-5dcf-48da-a12a-be58ab647f2a'
        cols_labor = [
            {"columnName": "PRODUCT_ID", "columnTableName": "PRODUCT"},
            {"columnName": "EVENT_ID", "columnTableName": "CLAIM"},
            {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "PRIM_LABOR_CD", "columnTableName": "CLAIM"},
            {"columnName": "EVENT_SUBMIT_DATE", "columnTableName": "CLAIM"}
        ]
        
        table_name = "DS_FINAL_GALACTO"
        launch_payload = {
            'launchColumnTables': ['PRODUCT', 'CLAIM'],
            'transposeFlag': 0,
            'launchKeyDim': 'PRODUCT',
            'tableName': table_name,
            'launchAppName': 'CAS',
            'launchColumns': cols_labor
        }
        res3 = await client.post(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json'}, json=launch_payload)
        if res3.status_code != 201:
            print('Launch Failed:', res3.text)
            return
            
        print(f'Launch Started for {new_id}')
        
        # Wait for launch to complete
        print('Waiting for launch to complete...')
        while True:
            await asyncio.sleep(5)
            chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
            items = chk.json().get('items', [])
            if not items: continue
            status = items[0].get('status')
            print('Status:', status)
            if status == 'COMPLETED':
                break
            elif status == 'FAILED':
                print('Launch failed.')
                return
asyncio.run(main())
