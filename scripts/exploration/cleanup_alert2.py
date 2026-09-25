import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        # CLEANUP ANALYSES
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers={'Authorization': f'Bearer {token}'})
        analyses = res.json().get('items', [])
        
        keep_analyses = ['Phase 1 - Pareto Alert 2 Fixed', 'Phase 2 - Stat Driver Alert 2 Fixed']
        
        for a in analyses:
            name = a.get('name', '')
            if 'Alert 2' in name and name not in keep_analyses:
                if 'Phase' in name or 'StatDriverTest' in name:
                    print('Deleting Analysis:', name, a.get('id'))
                    await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{a.get("id")}', headers={'Authorization': f'Bearer {token}'})
        
        # CLEANUP DATA SELECTIONS
        res2 = await client.get('https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections?limit=1000', headers={'Authorization': f'Bearer {token}'})
        dss = res2.json().get('items', [])
        
        keep_ds = ['Phase 3 - Workmanship Base DS 3', 'Phase 3 - Hardware Base DS 3', 'Alert 2 Galacto 1-001 DS']
        
        for d in dss:
            name = d.get('name', '')
            if 'Base DS' in name and ('Alert 2' in name or 'Phase 3' in name):
                if name not in keep_ds:
                    print('Deleting DS:', name, d.get('id'))
                    await client.delete(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{d.get("id")}', headers={'Authorization': f'Bearer {token}'})

asyncio.run(main())
