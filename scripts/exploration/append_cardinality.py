import re

cardinality_file = r'C:\Users\germsz\OneDrive - SAS\Desktop\FQA_MCP\fqa_high_cardinality_plan.md'
rules_file = r'C:\Git\sas-mcp-server\knowledge\fqa\mcp_execution_rules.md'

with open(cardinality_file, 'r', encoding='utf-8') as f:
    cardinality_content = f.read()

# Replace the top heading
cardinality_content = re.sub(
    r'^# Reworked FQA High-Cardinality Variable Remediation Plan',
    '## 8. High Cardinality Remediation Strategy',
    cardinality_content,
    flags=re.MULTILINE
)

# Fix subheadings to be level 3 or 4
cardinality_content = re.sub(r'^## 1\.', '### 8.1', cardinality_content, flags=re.MULTILINE)
cardinality_content = re.sub(r'^## 2\.', '### 8.2', cardinality_content, flags=re.MULTILINE)
cardinality_content = re.sub(r'^## 3\.', '### 8.3', cardinality_content, flags=re.MULTILINE)

cardinality_content = re.sub(
    r'^# FQA High Cardinality Remediation - Assessment & Fixes',
    '## 9. FQA High Cardinality Remediation - Assessment & Fixes',
    cardinality_content,
    flags=re.MULTILINE
)
cardinality_content = re.sub(r'^## 1\.', '### 9.1', cardinality_content, flags=re.MULTILINE)
cardinality_content = re.sub(r'^## 2\.', '### 9.2', cardinality_content, flags=re.MULTILINE)
cardinality_content = re.sub(r'^## 3\.', '### 9.3', cardinality_content, flags=re.MULTILINE)
cardinality_content = re.sub(r'^## 4\.', '### 9.4', cardinality_content, flags=re.MULTILINE)

with open(rules_file, 'a', encoding='utf-8') as f:
    f.write('\n\n' + cardinality_content)

print('Appended successfully.')
