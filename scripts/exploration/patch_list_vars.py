import re
with open('C:\\Git\\sas-mcp-server\\src\\sas_mcp_server\\tools\\iot.py', 'r') as f:
    content = f.read()

new_func = r'''@mcp.tool()
async def list_fqa_data_model_variables_tool(ctx: Context) -> dict:
    """
    Dynamically generates the FQA Data Mart Dictionary by querying the underlying 
    CAS tables (PRODUCT, CLAIM, LABOR, PART) in QASMartStore for all available 
    variables and their cardinalities (distinct values) and missing value counts.
    
    This should be used to pre-validate variables before dynamically routing them 
    to analyses (like Statistical Drivers or Failure Relationships), ensuring 
    algorithms don't fail due to high cardinality or non-existent variables.
    """
    logger.info("--- TOOL USED: list_fqa_data_model_variables ---")
    token = await get_token(ctx)
    
    from .compute import execute_sas_code
    
    # 1. Fetch labels from the API for mapping
    col_labels = {}
    async with make_client(token) as client:
        res_cols = await client.get(f'{VIYA_ENDPOINT}/dataSelection/tables/columns?limit=10000')
        if res_cols.status_code == 200:
            for c in res_cols.json().get('items', []):
                col = c.get('name')
                label = c.get('displayLabel', c.get('label', ''))
                col_labels[col] = label

    # 2. Run simple.distinct on the dimension tables to get cardinality
    sas_code = """
    cas mySess;
    proc cas;
       simple.distinct result=rp / table={caslib="QASMartStore", name="PRODUCT"};
       print rp.Distinct;
       simple.distinct result=rc / table={caslib="QASMartStore", name="CLAIM"};
       print rc.Distinct;
       simple.distinct result=rl / table={caslib="QASMartStore", name="LABOR"};
       print rl.Distinct;
       simple.distinct result=rpa / table={caslib="QASMartStore", name="PART"};
       print rpa.Distinct;
    quit;
    """
    
    res = await execute_sas_code(sas_code, ctx, fresh_session=True)
    listing = res.get('listing', '')
    
    # 3. Parse the listing output
    lines = listing.split('\n')
    
    result_dict = {
        'PRODUCT': [],
        'CLAIM': [],
        'LABOR': [],
        'PART': []
    }
    
    current_table = None
    in_table = False
    import re as regex
    
    for line in lines:
        if 'Distinct Counts for PRODUCT' in line:
            current_table = 'PRODUCT'
            in_table = True
        elif 'Distinct Counts for CLAIM' in line:
            current_table = 'CLAIM'
            in_table = True
        elif 'Distinct Counts for LABOR' in line:
            current_table = 'LABOR'
            in_table = True
        elif 'Distinct Counts for PART' in line:
            current_table = 'PART'
            in_table = True
        elif in_table:
            # Parse the row: Column, Distinct, Missing
            m = regex.search(r'^\s*([A-Za-z0-9_]+)\s+(\d+)\s+(\d+)', line)
            if m:
                col = m.group(1)
                dist = int(m.group(2))
                miss = int(m.group(3))
                label = col_labels.get(col, '')
                result_dict[current_table].append({
                    'column': f"{current_table}.{col}",
                    'label': label,
                    'distinct_values': dist,
                    'missing_values': miss
                })
                
    return result_dict
'''

pattern = re.compile(r'@mcp\.tool\(\)\nasync def list_fqa_data_model_variables_tool.*?return \{"variables": \["PRODUCT\.MODEL_CD", "CLAIM\.PRIM_REPL_PART_CD", "CLAIM\.TOTAL_EVENT_AMT", "BUILD_PERIOD", "INSERVICE_PERIOD"\]\}\n', re.DOTALL)
content = pattern.sub(lambda _: new_func + '\n', content)

with open('C:\\Git\\sas-mcp-server\\src\\sas_mcp_server\\tools\\iot.py', 'w') as f:
    f.write(content)
