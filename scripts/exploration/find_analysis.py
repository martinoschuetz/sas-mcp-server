import requests
import subprocess
import json

def get_token():
    cmd = 'sas-viya --output text profile token'
    return subprocess.check_output(cmd, shell=True).decode('utf-8').strip()

token = get_token()
headers = {
    'Authorization': f'Bearer {token}',
    'Accept': 'application/json' # or application/vnd.sas.collection+json
}
url = 'https://ssem.sas.com/iotAnalysis/analyses?limit=1000' # wait, the base url is from the mcp context.
