import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Get Alert 2 to copy its filters
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/4092ac1f-43b4-49a9-b78c-9c003b09f4dd', headers={'Authorization': f'Bearer {token}'})
        ds = res.json()
        
        # Remove the PRIM_REPL_PART_CD filter
        filters = ds.get('filterCriteria', {}).get('0', [])
        new_filters = [f for f in filters if f.get('columnName') != 'PRIM_REPL_PART_CD']
        ds['filterCriteria']['0'] = new_filters
        
        # Create new DS
        name = 'Phase 3 - Broad Galacto Cohort'
        body = {
            'name': name,
            'creationType': 'DEFAULT',
            'filterCriteria': ds.get('filterCriteria'),
            'additionalAttributes': ds.get('additionalAttributes', [])
        }
        res2 = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json'}, json=body)
        if res2.status_code != 201:
            print('Failed to create DS:', res2.text)
            return
        
        new_id = res2.json().get('id')
        print(f'Created {name} with ID: {new_id}')
        
        # Launch it with LABOR and metrics
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
        
        table_name = "DS_" + new_id.replace('-', '_')[:24]
        launch_payload = {
            'launchColumnTables': ['PRODUCT', 'CLAIM', 'LABOR'],
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
                
        # Trigger Failure Relationships
        from sas_mcp_server.tools.iot import run_failure_relationships_analysis
        class Ctx: pass
        import sas_mcp_server.tools.iot
        
        async def dummy_token(ctx): return token
        sas_mcp_server.tools.iot.get_token = dummy_token
        
        folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
        print('Dispatching Workmanship Analysis...')
        await run_failure_relationships_analysis(
            name='Phase 3 - Broad Workmanship Sequence',
            data_selection_id=new_id,
            folder_id=folder_id,
            ctx=Ctx(),
            analysis_var='LABOR.LABOR_AMOUNT',
            report_var='CLAIM.PRIM_LABOR_CD',
            data_domain='PRODUCT,CLAIM,LABOR',
            rv_dim_column='CLAIM.PRIM_LABOR_CD',
            wait_for_completion=False
        )
        print('Analysis Dispatched!')

asyncio.run(main())
