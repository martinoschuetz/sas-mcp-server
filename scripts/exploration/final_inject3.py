
import asyncio, httpx, os, json
async def main():
    token = json.load(open(os.path.expanduser('~/.sas-mcp-server/credentials.json')))['Default']['access-token']
    async with httpx.AsyncClient(verify=False) as client:
        description = '''Root Cause Summary for Alert 3 (3-033 Fuel Tank Cover):
1. Phase 1 (Pareto) revealed that when the Fuel Tank Cover (3-033) is replaced, the highest cost concurrent labor codes are 'Replace Choke cable' (C-003), 'Replace Piston ring and circlip' (G-015), 'Replace Fuel filter' (C-004), and 'Replace Fuel injector' (C-006).
2. Phase 2 (Statistical Drivers) identified Selling Dealer as the top driver, specifically flagging dealerships in harsh or extreme environments (e.g., Saint Paul MN, Aberdeen SD, Waco TX).
3. Conclusion: The Fuel Tank Cover is likely experiencing seal failure in harsh environmental conditions (extreme temperature fluctuations, dust, or winter salt). Once the seal fails, environmental contaminants enter the fuel system. This collateral contamination clogs the fuel filters, damages the fuel injectors, and ultimately leads to severe internal engine damage requiring piston ring replacement. 
Recommendation: Engineering should investigate the environmental resilience of the 3-033 fuel tank cover seal.'''
        
        # Inject into Alert 3 DS
        aid = 'bda3afa2-ff10-4f0f-bc16-3d78d1d5e734'
        chk = await client.get(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid}', headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.data.selection+json'})
        ds = chk.json()
        etag = chk.headers.get('Etag')
        ds['description'] = description
        await client.put(f'https://iot.viya-azure-gpu.unx.sas.com/dataSelection/dataSelections/{aid}', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/vnd.sas.data.selection+json', 'Accept': 'application/vnd.sas.data.selection+json', 'If-Match': etag}, json=ds)
        print('Injected!')
asyncio.run(main())

