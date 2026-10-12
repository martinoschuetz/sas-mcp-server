import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': 'germsz', 'password': '<REDACTED-USE-VIYA_PASSWORD-ENV-VAR>'},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json', 'Content-Type': 'application/json'}
        payload = {
            "name": "analysis",
            "items": [{
                "name": "SVDD_new_5_min_mean",
                "modelName": "SVDD_new",
                "dataSelectionId": "bde8497e-efd6-4f29-b8db-90b6f7124a72",
                "folderID": "142bf6ef-87f4-4a47-9357-94d21e37a6e7"
            }]
        }
        res = client.post(f'{base_url}/iotAnalysis/analyses', headers=headers, json=payload)
        print("Status:", res.status_code)
        print("Response:", res.text)
