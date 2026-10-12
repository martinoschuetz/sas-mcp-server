import os

filepath = r"C:\Git\sas-mcp-server\src\sas_mcp_server\tools\_access.py"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

read_tool = '    "get_iot_analysis_step_log_tool",\n'
write_tools = '    "update_analysis_step_parameters_tool",\n    "run_analysis_step_and_wait_tool",\n'

if 'get_iot_analysis_step_log_tool' not in content:
    content = content.replace('    "get_iot_analysis_run_status_tool",', '    "get_iot_analysis_run_status_tool",\n' + read_tool)
if 'update_analysis_step_parameters_tool' not in content:
    content = content.replace('    "create_child_analysis_and_run_tool",', '    "create_child_analysis_and_run_tool",\n' + write_tools)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
