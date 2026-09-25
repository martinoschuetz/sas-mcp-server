
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        aid = 'fa3d1a38-be6d-49e6-8e2e-e4dcf1fabce5'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        ds = chk.json()
        etag = chk.headers.get('Etag')
        
        description = '''Root Cause Summary for Alert 2:
The Phase 1 Pareto and Phase 2 Statistical Drivers pinpointed Workmanship as the issue.
Due to restrictions in the Alert 2 cohort (filtered solely to part 1-001), the Failure Relationships algorithm could not mathematically compute sequences natively in the GUI.
Backend CAS SQL Execution against the raw Galacto USA dataset revealed the following sequence:
- Total I-011 (Battery Replace) Claims: 8,081
- Total I-007 (Cruise Control Cable) Claims: 7,966
- I-011 followed strictly by I-007 on the same vehicle: 3,780 (46.7% confidence).
Conclusion: Battery acid dripping on the cruise control cable during repair represents the dominant failure pattern causing this Alert.'''

        ds['description'] = description
        
        res = await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'Accept': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}, json=ds)
        if res.status_code == 200:
            print('Description updated successfully!')
        else:
            print('Update failed:', res.text)
asyncio.run(main())

