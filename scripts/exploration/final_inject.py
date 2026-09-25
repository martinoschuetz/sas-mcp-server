
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        description = '''Root Cause Summary for Alert 2:
1. Phase 1 (Pareto) & Phase 2 (Statistical Drivers) pinpointed Workmanship issues in USA dealerships.
2. The Alert 2 cohort is filtered strictly to part 1-001, which mathematically prevents Failure Relationships from finding sequential patterns across different parts or labor codes in the native FQA GUI (yielding nosequencesfound_warning).
3. Backend CAS SQL Execution via the MCP Server against the raw broad Galacto USA dataset revealed the true sequence:
- Total I-011 (Battery Replace) Claims: 8,081
- Total I-007 (Cruise Control Cable) Claims: 7,966
- I-011 followed strictly by I-007 on the same vehicle: 3,780 (46.7% confidence).
Conclusion: Battery acid dripping on the cruise control cable during repair represents the dominant failure pattern causing this Alert.'''
        
        # Inject into Phase 3
        aid = 'd04c6530-261c-488a-8358-6e2fc36301f4'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        ds = chk.json()
        etag = chk.headers.get('Etag')
        ds['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'Accept': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}, json=ds)
        
        # Inject into Alert 2
        aid2 = '4092ac1f-43b4-49a9-b78c-9c003b09f4dd'
        chk2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds2 = chk2.json()
        etag2 = chk2.headers.get('Etag')
        ds2['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json', 'If-Match': etag2}, json=ds2)

        print('Descriptions updated successfully!')
asyncio.run(main())

