import ast
import json

with open(r'C:\Git\sas-mcp-server\src\sas_mcp_server\tools\iot.py', 'r', encoding='utf-8') as f:
    code = f.read()

tree = ast.parse(code)
functions = []
for node in ast.walk(tree):
    if isinstance(node, ast.AsyncFunctionDef) and (node.name.endswith('_analysis_tool') or node.name.endswith('_alert_tool')):
        functions.append(node)

output = []
for f in functions:
    docstring = ast.get_docstring(f) or 'No description provided.'
    args = []
    
    num_args = len(f.args.args)
    num_defaults = len(f.args.defaults)
    num_no_defaults = num_args - num_defaults
    
    for i, arg in enumerate(f.args.args):
        if arg.arg in ('ctx', 'token'):
            continue
            
        arg_info = {'name': arg.arg}
        
        if arg.annotation:
            try:
                # Use ast.unparse for Python 3.9+ to get string representation
                arg_info['type'] = ast.unparse(arg.annotation)
            except Exception:
                arg_info['type'] = 'Any'
        else:
            arg_info['type'] = 'Any'
            
        if i >= num_no_defaults:
            default_ast = f.args.defaults[i - num_no_defaults]
            try:
                arg_info['default'] = ast.unparse(default_ast)
            except Exception:
                arg_info['default'] = 'Complex Default'
        else:
            arg_info['default'] = 'Required'
            
        args.append(arg_info)
        
    output.append({'name': f.name, 'doc': docstring, 'args': args})

with open('fqa_docs.json', 'w') as out:
    json.dump(output, out, indent=2)
