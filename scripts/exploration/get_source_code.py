import httpx
import json

base_url = 'https://iot.viya-azure-gpu.unx.sas.com'
client = httpx.Client(verify=False)

res = client.post(f'{base_url}/SASLogon/oauth/token', 
                  data={'grant_type': 'password', 'username': 'germsz', 'password': '65!9IdimuuxIoT'},
                  auth=('sas.cli', ''))
token = res.json().get('access_token')
headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

# Fetch SVDD_ASSET model
res = client.get(f'{base_url}/iotAnalysisModels/models/SVDD/steps/SVDD_ASSET_2', headers=headers)
print(res.json().get('code', '')[:1000])
