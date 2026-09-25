
with open('tests/test_integration.py') as f:
    content = f.read()

replacement = '''
    "update_data_selection_tool": "test_iot_workflow",
    "get_genai_agent": "test_genai_workflow",
    "list_genai_agents": "test_genai_workflow",
    "list_genai_llms": "test_genai_workflow",
    "list_genai_sources": "test_genai_workflow",
    "query_genai_agent": "test_genai_workflow",
}'''

content = content.replace('    "update_data_selection_tool": "test_iot_workflow",\n}', replacement)

with open('tests/test_integration.py', 'w') as f:
    f.write(content)
