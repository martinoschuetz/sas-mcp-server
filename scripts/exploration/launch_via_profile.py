import asyncio
import os
import json
import uuid
import httpx
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth['Default']['access-token']
    
    ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection.launch+json', 'Content-Type': 'application/json'}
    
    async with httpx.AsyncClient(verify=False) as client:
        # First, fetch the parent DS to get its launch profile/columns
        # Wait, the parent DS had ID 818c2846-9b4e-4a86-a9b6-4282dfdb538e which was 404...
        # So we can't easily fetch it. Let's just provide the columns manually.
        
        cols = [
            {"columnName": "CLAIMCOST", "columnTableName": "CLAIM"},
            {"columnName": "LABOR_CODE", "columnTableName": "CLAIM"},
            {"columnName": "MODEL_CD", "columnTableName": "PRODUCT"},
            {"columnName": "EVENT_MONTH", "columnTableName": "CLAIM"},
            {"columnName": "STATE_PROVINCE_CD", "columnTableName": "CLAIM"},
            {"columnName": "REPL_PART_CD", "columnTableName": "CLAIM"},
            {"columnName": "PRIM_REPL_PART_CD", "columnTableName": "CLAIM"},
            {"columnName": "MODEL_YR", "columnTableName": "PRODUCT"},
            {"columnName": "PRODUCTION_DATE", "columnTableName": "PRODUCT"},
            {"columnName": "SELLING_DEALER_COUNTRY_CD", "columnTableName": "PRODUCT"}
        ]
        
        # But wait! There is a trick in FQA. You can get the "suggested" launch payload via:
        # GET /dataSelection/dataSelections/{ds_id}/launchProfile
        # Let's try that first to see if FQA gives us a ready-to-go payload!
        res_prof = await client.get(f"https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{ds_id}/launchProfile", headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
        if res_prof.status_code == 200:
            print("Found launch profile!")
            launch_body = res_prof.json()
            # Clean up the payload for POST
            if 'id' in launch_body:
                del launch_body['id']
            if 'links' in launch_body:
                del launch_body['links']
            if 'version' in launch_body:
                del launch_body['version']
            
            # The launch profile usually doesn't have tableName
            launch_body['tableName'] = f"DS_{ds_id.replace('-', '_')[:24]}"
            launch_body['transposeFlag'] = 0
            
            url = f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{ds_id}/launches'
            res = await client.post(url, headers=headers, json=launch_body)
            print("Launch Creation:", res.status_code, res.text[:200])
            
            if res.status_code in [200, 201]:
                job_url = f"https://iot.viya-azure-gpu.unx.sas.com/jobExecution/jobs/{res.json()['id']}"
                while True:
                    res_job = await client.get(job_url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
                    state = res_job.json().get('state')
                    print("Launch state:", state)
                    if state in ['completed', 'failed']:
                        break
                    await asyncio.sleep(2)
        else:
            print("Could not get launch profile:", res_prof.status_code, res_prof.text)

if __name__ == '__main__':
    asyncio.run(main())
