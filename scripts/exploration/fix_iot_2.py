
with open('src/sas_mcp_server/tools/iot.py') as f:
    lines = f.readlines()

out = []
for i, line in enumerate(lines):
    # Fix get_json -> _get_json, etc.
    line = line.replace('await get_json(', 'await _get_json(')
    line = line.replace('await post_json(', 'await _post_json(')
    line = line.replace('await put_json(', 'await _put_json(')
    line = line.replace('await delete_resource(', 'await _delete_resource(')
    line = line.replace('await get_paged_items(', 'await _get_paged_items(')
    
    out.append(line)

# Add imports at the very top (after first few lines)
out.insert(5, "import json\n")
out.insert(6, "from ..viya_utils import make_session_helpers\n")

# Add viya_session inside register
for i, line in enumerate(out):
    if line.startswith('    """Register IoT / FQA tools."""'):
        out.insert(i + 1, '    viya_session, _ = make_session_helpers(get_token)\n')
        break

with open('src/sas_mcp_server/tools/iot.py', 'w') as f:
    f.writelines(out)

print("Fixed iot.py again")
