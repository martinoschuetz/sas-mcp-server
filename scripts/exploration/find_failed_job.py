import httpx
import os
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
        res = client.get(f'{base_url}/iotAnalysis/analyses?limit=5000', headers=headers)
        data = res.json()
        items = data.get('items', [])
        for item in items:
            if item.get('name') == 'SVDD_new_5_min_mean':
                print(f"ID: {item['id']} NAME: {item['name']} MODEL: {item['modelName']}")
