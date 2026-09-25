import re
with open('C:\\Git\\sas-mcp-server\\src\\sas_mcp_server\\prompts.py', 'r') as f:
    content = f.read()

new_prompt = '''@mcp.prompt()
def fqa_best_practices() -> list[Message]:
    """Provide the core business rules and guidelines for working with SAS FQA Data Selections and Analyses."""
    # We dynamically read the rule file so that any future changes to .agents/rules/fqa.md are reflected instantly.
    import os
    rule_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.agents', 'rules', 'fqa.md')
    try:
        with open(rule_path, 'r', encoding='utf-8') as f:
            rules_content = f.read()
    except Exception as e:
        rules_content = f"Could not read FQA rules file from {rule_path}: {e}"
        
    return [Message(role="user", content=(
        f"You are a SAS FQA expert. Always adhere strictly to the following architectural "
        f"and analytical guidelines when constructing workflows or launching analyses via the MCP Server:\\n\\n"
        f"{rules_content}\\n\\n"
        f"Keep these rules in context for all FQA-related tasks."
    ))]

'''

content = content + '\n' + new_prompt

with open('C:\\Git\\sas-mcp-server\\src\\sas_mcp_server\\prompts.py', 'w') as f:
    f.write(content)
