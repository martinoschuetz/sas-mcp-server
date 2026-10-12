import httpx
import json
import os

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'

with httpx.Client(verify=False) as client:
    res = client.post(f'{base_url}/SASLogon/oauth/token', 
                      data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                      auth=('sas.cli', ''))
    token = res.json().get('access_token')

    if token:
        headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
        res = client.get(f'{base_url}/iotAnalysis/analyses?limit=5000', headers=headers)
        items = res.json().get('items', [])
        
        source = None
        target = None
        for item in items:
            name = item.get('name', '')
            if name == 'SVDD 5 min mean':
                source = item
            elif 'new' in name.lower() and '5' in name and 'min' in name.lower():
                print(f"Potential target found: '{name}' (ID: {item['id']})")
                target = item
                
        print(f"Source ID: {source['id'] if source else 'Not found'}")
        print(f"Target ID: {target['id'] if target else 'Not found'}")
