
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        description = '''Root Cause Summary for Alert 1:
1. Phase 1 (Pareto) showed the top labor codes are 'Replace Exhaust gasket', 'Replace Fuel injector', and 'Replace Adjusting mechanism'.
2. Phase 2 (Statistical Drivers) pinpointed Selling Dealer as the root cause, indicating a Workmanship issue.
3. Specifically, a subset of midwestern/eastern dealerships exhibits an outstandingly high failure rate compared to the 5% baseline:
   - Milwaukee, WI Dealership: 15.8% failure rate
   - Charleston, WV Dealership: 18.0% failure rate
   - Saint Paul, MN Dealership: 10.1% failure rate
Conclusion: Localized repair practices at these specific dealerships are driving the anomaly, likely related to improper handling of the exhaust gasket or fuel injectors during engine block (9-040) maintenance.'''
        
        # Inject into Phase 3
        aid = 'f92e06ba-8d75-4abb-bfc4-4ae034b9ceb4'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.iot.analysis+json'})
        ds = chk.json()
        etag = chk.headers.get('Etag')
        ds['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses/{aid}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.iot.analysis+json', 'Accept': 'application/vnd.sas.iot.analysis+json', 'If-Match': etag}, json=ds)
        
        # Inject into Alert 1
        aid2 = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        chk2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds2 = chk2.json()
        etag2 = chk2.headers.get('Etag')
        ds2['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json', 'If-Match': etag2}, json=ds2)

        print('Descriptions updated successfully!')
asyncio.run(main())

