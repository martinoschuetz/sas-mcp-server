import asyncio
from typing import Any
from sas_mcp_server.viya_utils import get_cached_session

async def main():
    session = await get_cached_session()
    # Let's get all analyses using the REST API
    res = await session.get("/iotAnalysis/analyses?limit=1000")
    data = res.json()
    items = data.get("items", [])
    
    # filter
    svdd_analyses = [a for a in items if "SVDD" in a.get("name", "")]
    for a in svdd_analyses:
        print(f"ID: {a['id']}, Name: {a['name']}, Type: {a['modelName']}, DS: {a['dataSelectionId']}")
        
if __name__ == '__main__':
    asyncio.run(main())
