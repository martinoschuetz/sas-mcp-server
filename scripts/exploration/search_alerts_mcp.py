import asyncio, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
from sas_mcp_server.tools.iot import list_data_selections
from sas_mcp_server.tools.iot import list_data_selections

async def main():
    ctx = None
    res = await list_data_selections(ctx)
    for ds in res.get('items', []):
        name = ds.get('name', '')
        if 'Alert' in name or 'alert' in name.lower() or '2' in name:
            print(f"DS: {name} ID: {ds.get('id')}")
asyncio.run(main())
