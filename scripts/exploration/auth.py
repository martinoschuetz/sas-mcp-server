import os

import httpx
from dotenv import load_dotenv

load_dotenv()
r = httpx.post(f'{os.environ["VIYA_ENDPOINT"]}/SASLogon/oauth/token', data={'grant_type': 'password', 'username': os.environ['VIYA_USERNAME'], 'password': os.environ['VIYA_PASSWORD']}, auth=('sas.cli', ''), verify=False, timeout=5.0)
access_token = r.json()['access_token']
url = f'{os.environ["VIYA_ENDPOINT"]}/casManagement/servers/cas-shared-default/caslibs'
print('GET', url)
res = httpx.get(url, headers={'Authorization': f'Bearer {access_token}', 'Accept': 'application/json'}, verify=False, timeout=5.0)
print(res.status_code)