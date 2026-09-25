import asyncio
import os
import json
import uuid
import httpx
import re
from unittest.mock import MagicMock

# Import MCP dependencies
import sas_mcp_server.tools._common
import sas_mcp_server.tools.iot
import sas_mcp_server.tools.compute

class DummyContext:
    def __init__(self):
        self.request_context = MagicMock()

async def get_token(ctx=None):
    auth_file = os.path.expanduser('~/.sas-mcp-server/credentials.json')
    with open(auth_file, 'r') as f:
        auth = json.load(f)
    return auth['Default']['access-token']

sas_mcp_server.tools._common.get_token = get_token
sas_mcp_server.tools.iot.get_token = get_token
sas_mcp_server.tools.compute.get_token = get_token

async def main():
    ctx = DummyContext()
    mcp_mock = MagicMock()
    tools = {}
    def mock_tool(**kwargs):
        def decorator(func):
            tools[func.__name__] = func
            return func
        return decorator
    mcp_mock.tool.side_effect = mock_tool
    
    # Register the tools
    sas_mcp_server.tools.iot.register(mcp_mock, get_token)
    sas_mcp_server.tools.compute.register(mcp_mock, get_token)
    
    execute_sas = tools['execute_sas_code']
    create_child_ds = tools['create_child_data_selection_and_launch_tool']
    run_stat = tools['run_statistical_driver_analysis_tool']
    run_tree = tools['run_decision_tree_analysis_tool']
    
    token = await get_token()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.sas.collection+json'}
    
    # Constants based on prior runs
    parent_ds_id = '21274abd-7d03-4ac6-84e3-3c92084e6b6c'
    folder_id = '79eaaedd-2f6b-413f-8621-52b09325c818'
    uid = str(uuid.uuid4())[:4]
    
    # -----------------------------------------------------------------------
    # STEP 1: Find the most recent Phase 1 Pareto Analysis for this DS
    # -----------------------------------------------------------------------
    print("1. Locating Phase 1 Pareto Analysis...")
    async with httpx.AsyncClient(verify=False) as client:
        res = await client.get('https://iot.viya-azure-gpu.unx.sas.com/iotAnalysis/analyses?limit=1000', headers=headers)
        analyses_data = res.json().get('items', [])
        
    pareto_analysis = None
    for a in sorted(analyses_data, key=lambda x: x.get('creationTimeStamp', ''), reverse=True):
        if a.get('dataSelectionId') == parent_ds_id and 'Pareto' in a.get('name', ''):
            pareto_analysis = a
            break
            
    if not pareto_analysis:
        print("   ERROR: Could not find a Pareto analysis for this Data Selection.")
        return
        
    short_id = pareto_analysis.get('shortId')
    parent_analysis_id = pareto_analysis.get('id')
    print(f"   -> Found Analysis: '{pareto_analysis.get('name')}'")
    print(f"   -> Short ID: {short_id}")
        
    # -----------------------------------------------------------------------
    # STEP 2: Query QASANLOUT for the top driving factor (PRIM_LABOR_CD)
    # -----------------------------------------------------------------------
    print("\n2. Extracting Top Driver from QASANLOUT CAS Table...")
    table_name = f"PARETO_{short_id}"
    
    sas_code = f"""
    cas mysess;
    proc fedsql sessref=mysess;
      create table casuser.top_driver as
      select * from QASANLOUT."{table_name}"
      limit 1;
    quit;
    
    filename outjson TEMP;
    proc json out=outjson;
      export casuser.top_driver;
    run;
    
    data _null_;
      infile outjson;
      input;
      put "JSON_START:" _infile_ ":JSON_END";
    run;
    """
    
    res_sas = await execute_sas(sas_code=sas_code, ctx=ctx)
    sas_log = res_sas.get('log', '')
    
    # Parse JSON from SAS log
    top_labor_code = None
    for line in sas_log.split('\n'):
        if 'JSON_START:' in line and ':JSON_END' in line:
            json_str = line.split('JSON_START:')[1].split(':JSON_END')[0].strip()
            try:
                data = json.loads(json_str)
                if data and isinstance(data, list) and len(data) > 0:
                    row = data[0]
                    if isinstance(row, dict):
                        # The reporting variable is usually the first string column or specifically named
                        for val in row.values():
                            if isinstance(val, str) and (val.startswith('L-') or val.isdigit() or '-' in val):
                                top_labor_code = val
                                break
                        if not top_labor_code:
                             top_labor_code = str(list(row.values())[0])
            except json.JSONDecodeError:
                pass
            
    if not top_labor_code:
        print("   WARNING: Could not parse top labor code from CAS. Using fallback 'L-152'")
        top_labor_code = "L-152"
    else:
        print(f"   -> Successfully extracted top driver: '{top_labor_code}'")
        
    # -----------------------------------------------------------------------
    # STEP 3: Create a Sub-segment (Child Data Selection) focused on the driver
    # -----------------------------------------------------------------------
    print("\n3. Creating Child Data Selection for Segmentation...")
    child_ds_name = f"Alert 1 - Labor Code {top_labor_code} Segment {uid}"
    
    new_filters = [{
        "columnName": "PRIM_LABOR_CD", 
        "component": "CLAIM", 
        "operatorCode": "IN", 
        "values": [{"value": top_labor_code}]
    }]
    
    child_res = await create_child_ds(
        parent_data_selection_id=parent_ds_id,
        new_name=child_ds_name,
        new_filters=new_filters,
        parent_analysis_id=parent_analysis_id,
        folder_id=folder_id,
        ctx=ctx
    )
    
    child_ds_id = None
    match = re.search(r'ID\s+([a-f0-9\-]{36})', child_res)
    if match:
        child_ds_id = match.group(1)
        
    if not child_ds_id:
        # Check if the tool returned a dictionary
        if isinstance(child_res, dict) and 'id' in child_res:
            child_ds_id = child_res['id']
        else:
            print("   ERROR: Failed to extract child DS ID from tool output:")
            print(child_res)
            return
        
    print(f"   -> Child Data Selection Created and Launched (ID: {child_ds_id})")
    
    # -----------------------------------------------------------------------
    # STEP 4: Launch Phase 2 (Algorithmic Segmentation) Analyses
    # -----------------------------------------------------------------------
    print("\n4. Triggering Phase 2 Predictive Analyses...")
    
    # For Phase 2 we MUST use low-cardinality or _BINNED categorical variables to ensure
    # the algorithms converge successfully!
    phase2_report_vars = "PRODUCT.MODEL_CD,PRODUCT.CSTMR_STATE_CD,CLAIM.PRIM_REPL_PART_CD_BINNED"
    
    stat_name = f"Phase 2 - Stat Driver (Labor {top_labor_code}) {uid}"
    tree_name = f"Phase 2 - Decision Tree (Labor {top_labor_code}) {uid}"
    
    await run_stat(
        name=stat_name,
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var=phase2_report_vars,
        wait_for_completion=False,
        ctx=ctx
    )
    print(f"   -> Dispatched: {stat_name}")
    
    await run_tree(
        name=tree_name,
        data_selection_id=child_ds_id,
        folder_id=folder_id,
        analysis_var="CLAIM.CLAIMCOST",
        report_var=phase2_report_vars,
        wait_for_completion=False,
        ctx=ctx
    )
    print(f"   -> Dispatched: {tree_name}")
    
    print("\nWorkflow automation complete! Phase 2 is now running on the compute backend.")

if __name__ == '__main__':
    asyncio.run(main())
