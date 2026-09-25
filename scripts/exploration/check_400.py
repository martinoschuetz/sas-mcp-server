import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        body = {
            "name": "analysis",
            "items": [
                {
                    "name": "StatDriverTest123",
                    "modelName": "STATDRIVER_PRODUCT",
                    "dataSelectionId": "4092ac1f-43b4-49a9-b78c-9c003b09f4dd",
                    "folderID": "79eaaedd-2f6b-413f-8621-52b09325c818"
                }
            ]
        }
        res = await client.post('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json', 'Accept': 'application/json'}, json=body)
        print(res.status_code)
        print(res.text)
asyncio.run(main())
