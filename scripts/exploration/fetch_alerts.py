import json
import os
import asyncio
from sas_mcp_server.viya_client import make_client
from sas_mcp_server.config import VIYA_ENDPOINT

async def main():
    auth_file = os.path.expanduser('~/.gemini/.sas-auth')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    token = auth.get('access_token')

    async with make_client(token) as client:
        resp = await client.get(
            f'{VIYA_ENDPOINT}/iotAnalysis/analyses/818c2846-9b4e-4a86-a9b6-4282dfdb538e/alerts?limit=1000',
            headers={'Accept': 'application/vnd.sas.collection+json'}
        )
        data = resp.json()
        items = data.get('items', [])
        # Sort by cost_score descending
        items.sort(key=lambda x: float(x.get('cost_score', 0) or 0), reverse=True)
        for i, item in enumerate(items[:5]):
            print(f"{i+1}. **Part:** {item.get('PRIM_REPL_PART_CD')} - {item.get('PRIM_REPL_PART_CD_DESC')} | **Model:** {item.get('MODEL_CD')} ({item.get('MODEL_CD_DESC')}) | **Cost Score:** {item.get('cost_score'):.2f} | **Alert Duration:** {item.get('alert_start_date')} to {item.get('alert_end_date')} ({item.get('Alert_Duration_MONTH')} months) | **Score:** {item.get('score'):.2f}")

if __name__ == '__main__':
    asyncio.run(main())
