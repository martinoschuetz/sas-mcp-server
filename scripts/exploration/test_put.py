import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # Copy
        import uuid
        name = f"Test_{uuid.uuid4().hex[:4]}"
        copy_res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/7d23ef73-9066-43b3-9196-03ab8ace3947/copy', json={'name': name}, headers={'Authorization': f'Bearer {token}'})
        new_ds = copy_res.json()
        new_id = new_ds['id']
        print('Copied:', new_id)
        
        # Add filter
        new_ds['filterCriteria']['0'].append({
            'columnName': 'LABOR_CD',
            'operatorCode': 'IN',
            'componentTypeCode': 'LABOR',
            'component': 'LABOR',
            'filterAttributeId': 'LABOR_CD_LABOR',
            'groupId': '0',
            'uiDisplay': False,
            'values': ['ZZZ']
        })
        
        # PUT
        put_res = await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}', json=new_ds, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'If-Match': '*'})
        print('PUT:', put_res.status_code)
        
        # Launch it
        launch_body = {'id': new_id, 'transposeFlag': True}
        l_res = await client.post(
            f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{new_id}/launches', 
            json=launch_body, 
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection.launch+json', 'Accept': 'application/vnd.sas.data.selection.launch+json'}
        )
        print('Launch code:', l_res.status_code)
        if l_res.status_code == 201:
            print('Launch Job ID:', l_res.json().get('id'))
asyncio.run(main())
