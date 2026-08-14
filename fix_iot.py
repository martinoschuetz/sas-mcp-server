import sys

with open('src/sas_mcp_server/tools/iot.py', 'r') as f:
    lines = f.readlines()

out = []
for i, line in enumerate(lines):
    # Add import json at the top
    if 'import asyncio' in line:
        out.append(line)
        out.append('import json\n')
        continue
    
    # Add make_session_helpers
    if 'from ..viya_utils import run_one_snippet, get_context_id' in line:
        out.append('from ..viya_utils import run_one_snippet, get_context_id, make_session_helpers\n')
        continue
    
    # Add viya_session inside register
    if line.startswith('    """Register IoT / FQA tools."""'):
        out.append(line)
        out.append('    viya_session, _ = make_session_helpers(get_token)\n')
        continue

    # Fix get_json -> _get_json, etc.
    line = line.replace('await get_json(', 'await _get_json(')
    line = line.replace('await post_json(', 'await _post_json(')
    line = line.replace('await put_json(', 'await _put_json(')
    line = line.replace('await delete_resource(', 'await _delete_resource(')
    line = line.replace('await get_paged_items(', 'await _get_paged_items(')
    
    out.append(line)

with open('src/sas_mcp_server/tools/iot.py', 'w') as f:
    f.writelines(out)

print("Fixed iot.py")
