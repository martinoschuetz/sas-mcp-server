import os
import glob
import re
import yaml

def get_python_endpoints():
    endpoints = []
    pattern = re.compile(r'f?\"(/[^\"\?]+)\??')
    
    for py_file in glob.glob('src/sas_mcp_server/**/*.py', recursive=True):
        with open(py_file, 'r', encoding='utf-8') as f:
            for line_no, line in enumerate(f, 1):
                if any(x in line for x in ['client.get', 'client.post', 'client.put', 'client.delete', '_get_json', '_post_json', '_put_json', '_delete_resource', 'VIYA_ENDPOINT', 'mcp.custom_route']):
                    matches = pattern.findall(line)
                    for m in matches:
                        if m.startswith('/') and not m.startswith('//'):
                            clean_endpoint = re.sub(r'\{[^}]+\}', '{}', m)
                            endpoints.append((py_file, line_no, m, clean_endpoint))
    return endpoints

def get_swagger_paths():
    swagger_paths = {}
    for yaml_file in glob.glob('docs/APIs/**/*.yml', recursive=True):
        try:
            with open(yaml_file, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)
                if 'paths' in data:
                    for path in data['paths'].keys():
                        clean_path = re.sub(r'\{[^}]+\}', '{}', path)
                        swagger_paths[clean_path] = (yaml_file, path)
        except Exception as e:
            pass
    return swagger_paths

print("Extracting endpoints from code...")
python_endpoints = get_python_endpoints()

print("Extracting paths from OpenAPI specs...")
swagger_paths = get_swagger_paths()

print("\n--- Validation Results ---")
missing = []
found = []
for py_file, line, orig, clean in set(python_endpoints):
    matched = False
    # Exclude internal fastmcp/health endpoints
    if clean in ['/health', '/mcp', '/SASLogon/oauth/token', '/SASLogon/logout', '/SASLogon/oauth/device_authorization']:
        continue
        
    for sp in swagger_paths.keys():
        if clean == sp or clean.rstrip('/') == sp.rstrip('/'):
            matched = True
            break
            
    if matched:
        found.append(orig)
    else:
        # Try looser match: some python endpoints append sub-resources dynamically
        for sp in swagger_paths.keys():
            if clean.startswith(sp + '/') or sp.startswith(clean + '/'):
                matched = True
                break
        if not matched:
            missing.append((orig, py_file, line))

print(f"Matched {len(set(found))} endpoints successfully.")
if missing:
    print(f"\nWarning: Found {len(set(missing))} endpoints in Python that don't clearly match downloaded OpenAPI specs:")
    for orig, py_file, line in sorted(set(missing)):
        print(f"  {py_file}:{line} -> {orig}")
else:
    print("\nAll Python endpoints match OpenAPI specs!")
