import re

with open('src/sas_mcp_server/tools/iot.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace poll_job
replacement_poll_job = '''
async def poll_job(job_url: str, token: str, poll_interval: float = 1.0) -> dict:
    \"\"\"Polls a job status until it reaches a terminal state.\"\"\"
    async with make_client(token) as client:
        while True:
            resp = await client.get(f"{VIYA_ENDPOINT}{job_url}", headers={"Accept": "application/json"})
            resp.raise_for_status()
            status_data = resp.json()
            state = status_data.get("state")
            if state in ["completed", "failed", "cancelled"]:
                return status_data
            await asyncio.sleep(poll_interval)
            # Exponential backoff up to 10s
            poll_interval = min(poll_interval * 1.5, 10.0)
'''

pattern1 = re.compile(r'async def poll_job.*?await asyncio\.sleep\(poll_interval\)', re.DOTALL)
if pattern1.search(content):
    content = pattern1.sub(replacement_poll_job.strip(), content)
    print('Patched poll_job')

# Replace the hardcoded wait asyncio.sleep(1) in the two manual polling loops
# Loop 1: launch_status
pattern2 = re.compile(r'launch_status == "COMPLETED":\s+break\s+elif launch_status in \("FAILED", "ERROR"\):\s+raise RuntimeError\(f"Data selection launch failed with status \{launch_status\}"\)\s+await asyncio\.sleep\(1\)', re.DOTALL)

replacement2 = '''launch_status == "COMPLETED":
                    break
                elif launch_status in ("FAILED", "ERROR"):
                    raise RuntimeError(f"Data selection launch failed with status {launch_status}")
                await asyncio.sleep(poll_interval)
                poll_interval = min(poll_interval * 1.5, 10.0)'''

# For the launch status, we need to initialize poll_interval
pattern2_init = re.compile(r'import asyncio\s+while True:')
replacement2_init = '''import asyncio
            poll_interval = 1.0
            while True:'''

content = pattern2_init.sub(replacement2_init, content)
content = pattern2.sub(replacement2, content)


# Loop 2: run_status
pattern3 = re.compile(r'run_status == "completed":\s+break\s+elif run_status in \("failed", "cancelled"\):\s+raise RuntimeError\(f"Analysis run failed with status \{run_status\}"\)\s+await asyncio\.sleep\(1\)', re.DOTALL)

replacement3 = '''run_status == "completed":
                    break
                elif run_status in ("failed", "cancelled"):
                    raise RuntimeError(f"Analysis run failed with status {run_status}")
                await asyncio.sleep(poll_interval)
                poll_interval = min(poll_interval * 1.5, 10.0)'''

# Wait, is 'import asyncio' there too?
pattern3_init = re.compile(r'import asyncio\s+run_resp_json = run_resp\.json\(\)\s+while True:')
replacement3_init = '''import asyncio
            run_resp_json = run_resp.json()
            poll_interval = 1.0
            while True:'''

content = pattern3_init.sub(replacement3_init, content)
content = pattern3.sub(replacement3, content)

with open('src/sas_mcp_server/tools/iot.py', 'w', encoding='utf-8') as f:
    f.write(content)
print('Patched iot.py')
