import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
data_selection_id = '98b6d93c-37e3-4e4d-845a-9538ffcb690d'
folder_id = '142bf6ef-87f4-4a47-9357-94d21e37a6e7' # Project QC
original_analysis_id = 'd723542d-3fda-4fa5-9580-9cbfb6d4f78e'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'}
        
        # 1. Get original parameters
        res = client.get(f'{base_url}/iotAnalysis/analyses/{original_analysis_id}', headers=headers)
        original_analysis = res.json()
        
        params_to_set = {}
        for step in original_analysis.get('steps', []):
            for param in step.get('inputParameters', []):
                params_to_set[param['parameterName']] = param['parameterValue']
                
        # 2. Create new analysis
        payload = {
            "name": "analysis",
            "items": [{
                "name": "SVDD_new_5_min_mean",
                "modelName": "SVDD_NEW",
                "dataSelectionId": data_selection_id,
                "folderID": folder_id
            }]
        }
        create_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
        res = client.post(f'{base_url}/iotAnalysis/analyses', headers=create_headers, json=payload)
        
        if res.status_code not in (200, 201):
            print("Failed to create:", res.text)
            exit(1)
            
        created_analysis = res.json()['items'][0]
        new_analysis_id = created_analysis['id']
        print(f"Created new analysis: {new_analysis_id}")
        
        # 3. Update all steps with original parameters
        res = client.get(f'{base_url}/iotAnalysis/analyses/{new_analysis_id}', headers=headers)
        new_analysis = res.json()
        etag = res.headers.get('ETag', '')
        
        for step in new_analysis.get('steps', []):
            for param in step.get('inputParameters', []):
                pname = param.get('parameterName')
                if pname in params_to_set:
                    param['parameterValue'] = params_to_set[pname]
                    
        update_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}
        res = client.put(f'{base_url}/iotAnalysis/analyses/{new_analysis_id}', headers=update_headers, json=new_analysis)
        
        if res.status_code == 200:
            print("Successfully updated parameters")
            # 4. Run step 1
            step_id = new_analysis['steps'][0]['id']
            run_headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
            res_run = client.post(f'{base_url}/iotAnalysis/analyses/{new_analysis_id}/steps/{step_id}/jobs', headers=run_headers, json={})
            print("Run status:", res_run.status_code)
        else:
            print("Failed to update:", res.status_code, res.text)
