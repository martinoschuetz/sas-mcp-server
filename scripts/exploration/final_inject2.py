
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        description = '''Root Cause Summary for Alert 1:
1. Phase 1 (Pareto) showed the top labor codes are 'Replace Exhaust gasket', 'Replace Fuel injector', and 'Replace Adjusting mechanism'.
2. Phase 2 (Statistical Drivers) pinpointed Selling Dealer as the root cause, indicating a Workmanship issue.
3. A subset of Midwestern dealerships exhibits an outstanding failure rate compared to the 5% baseline (e.g., Milwaukee WI at 15.8%, Saint Paul MN at 10.1%).
4. Phase 3 (Sequence Analysis via SQL) on the broader population reveals that out of 3,157 Engine Block (9-040) claims, 251 were subsequently followed by an Exhaust Gasket (D-003) replacement, and 241 exhibited the reverse sequence.
Conclusion: Localized repair practices at these specific dealerships are driving the anomaly, likely related to improper handling of the exhaust gasket during engine block maintenance.'''
        
        # Inject into Alert 1
        aid2 = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
        chk2 = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds2 = chk2.json()
        etag2 = chk2.headers.get('Etag')
        ds2['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid2}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json', 'If-Match': etag2}, json=ds2)

        print('Description updated successfully!')
asyncio.run(main())

