import re

from sas_mcp_server import tools

groups = {num: title for num, title in tools.TIER_TITLES.items()}
modules = {
    0: tools.compute,
    1: tools.discovery,
    2: tools.data_ops,
    3: tools.reports,
    4: tools.jobs,
    5: tools.automl,
    6: tools.model_scoring,
    7: tools.decisioning,
    8: tools.workbench,
    9: tools.iot,
    10: tools.genai
}

output = []
for tier_num, title in sorted(groups.items()):
    output.append(f'## {title}')
    mod = modules[tier_num]
    
    with open(mod.__file__) as f:
        content = f.read()
    
    matches_async = re.findall(r'@mcp\.tool(?:\(\))?\s+async def ([a-zA-Z0-9_]+)', content)
    matches_sync = re.findall(r'@mcp\.tool(?:\(\))?\s+def ([a-zA-Z0-9_]+)', content)
    matches_name = re.findall(r'@mcp\.tool\(name=["\']([a-zA-Z0-9_]+)["\']\)', content)
    
    all_tools = sorted(set(matches_async + matches_sync + matches_name))
    for t in all_tools:
        output.append(f'- {t}')
    output.append('')

with open("tools_list.md", "w") as f:
    f.write('\n'.join(output))
