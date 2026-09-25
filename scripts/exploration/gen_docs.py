import json
import os

with open('fqa_docs.json', 'r') as f:
    docs = json.load(f)

md = []
md.append('# SAS Analytics for IoT (FQA) Users Guide\n')
md.append('This document provides a comprehensive overview of the FQA Analysis Types and Emerging Issue capabilities that can be invoked programmatically via the API (Modified = "System" and Data Domain = "Products").\n')

# Separate standard analyses from emerging issues
emerging = [d for d in docs if 'emerging' in d['name'].lower()]
standard = [d for d in docs if 'emerging' not in d['name'].lower() and d['name'].startswith('run_') and d['name'] != 'run_iot_analysis_tool' and d['name'] != 'run_iot_analysis_and_wait_tool']

md.append('## 1. Emerging Issue Capabilities\n')
for d in emerging:
    md.append(f'### {d["name"]}')
    doc = d["doc"].strip() if d["doc"] else "No description provided."
    md.append(f'{doc}\n')
    md.append('**Parameters:**')
    md.append('| Parameter | Type | Default / Constraint |')
    md.append('|---|---|---|')
    for arg in d['args']:
        default_val = arg.get("default", "")
        if default_val is None:
            default_val = "None"
        elif default_val == "":
            default_val = '""'
        md.append(f'| `{arg["name"]}` | `{arg.get("type", "Any")}` | `{default_val}` |')
    md.append('\n')

md.append('## 2. Standard Analysis Types\n')
md.append('The following 14 FQA Analysis Configurations have been implemented as programmatic capabilities within the MCP Server. All analysis run tools require `name` and `data_selection_id` (the target population), along with a variety of analysis-specific parameters like the dependent variable (`analysis_var`) and the independent or grouping variables (`report_var`, `by_var`).\n')

for d in standard:
    name_clean = d['name'].replace('run_', '').replace('_analysis_tool', '').replace('_', ' ').title()
    if name_clean == 'Detail':
        name_clean = 'Details Table'
    md.append(f'### {name_clean} Analysis')
    md.append(f'Tool name: `{d["name"]}`\n')
    doc = d["doc"].strip() if d["doc"] else "No description provided."
    md.append(f'{doc}\n')
    md.append('**Parameters:**')
    md.append('| Parameter | Type | Default / Constraint |')
    md.append('|---|---|---|')
    for arg in d['args']:
        default_val = arg.get("default", "")
        if default_val is None:
            default_val = "None"
        elif default_val == "":
            default_val = '""'
        md.append(f'| `{arg["name"]}` | `{arg.get("type", "Any")}` | `{default_val}` |')
    md.append('\n')

out_path = r'C:\Users\germsz\OneDrive - SAS\Desktop\FQA_MCP\FQA_Users_Guide.md'
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, 'w', encoding='utf-8') as out:
    out.write('\n'.join(md))

print(f'Wrote docs to {out_path}')
