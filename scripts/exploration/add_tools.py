import re

def update_iot_py():
    with open('src/sas_mcp_server/tools/iot.py', 'r') as f:
        content = f.read()

    # 1. Update docstring and message in analyze_emerging_issue_alert_tool
    content = content.replace(
        '"status": "COMPLETED"',
        '"status": "SAVED"  # API forces dummy bookmark to SAVED'
    )
    content = content.replace(
        "is created with 'Completed' status",
        "is created with 'SAVED' status"
    )
    
    new_tools = """
    @mcp.tool()
    async def combine_data_selections_tool(new_name: str, base_ds_id: str, additional_ds_ids: list[str], ctx: Context, description: str = "") -> dict:
        \"\"\"
        Merges multiple Data Selections into a single new Data Selection by combining their filterCriteria.
        It copies the base Data Selection and merges filter values (using logical OR/IN) for matching column names from the additional Data Selections.
        \"\"\"
        import uuid
        import asyncio
        logger.info("--- TOOL USED: combine_data_selections_tool (%s) ---", new_name)
        token = await get_token(ctx)
        
        async with viya_session("combine_data_selections", ctx) as client:
            # 1. Copy the base DS
            copy_url = f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{base_ds_id}/copy"
            payload = {"name": new_name, "description": description}
            resp_copy = await client.post(copy_url, json=payload, headers={"Accept": "application/vnd.sas.data.selection+json"})
            resp_copy.raise_for_status()
            new_ds_id = resp_copy.json()["id"]

            # 2. Fetch all DS concurrently
            async def get_ds(ds_id):
                r = await client.get(f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{ds_id}", headers={"Accept": "application/vnd.sas.data.selection+json"})
                r.raise_for_status()
                return r.json(), r.headers.get("ETag", "")

            results = await asyncio.gather(*[get_ds(id_) for id_ in [new_ds_id] + additional_ds_ids])
            new_ds_details, etag = results[0]
            additional_dss = [r[0] for r in results[1:]]

            # 3. Merge filters in group '0'
            filter_criteria = new_ds_details.get("filterCriteria", {})
            group_0 = filter_criteria.get("0", [])
            
            for add_ds in additional_dss:
                add_fc = add_ds.get("filterCriteria", {}).get("0", [])
                for f_add in add_fc:
                    # Find matching column in group_0
                    match = next((f for f in group_0 if f["columnName"] == f_add["columnName"] and f.get("component") == f_add.get("component")), None)
                    if match:
                        # Merge values uniquely
                        combined = list(set(match.get("values", []) + f_add.get("values", [])))
                        match["values"] = combined
                    else:
                        # Append new rule entirely
                        new_f = dict(f_add)
                        new_f["id"] = str(uuid.uuid4())
                        new_f["criteriaGroupId"] = new_ds_id
                        group_0.append(new_f)
            
            new_ds_details["filterCriteria"]["0"] = group_0

            # 4. PUT updated DS
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{new_ds_id}", 
                json=new_ds_details, 
                headers={"If-Match": etag, "Content-Type": "application/json", "Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_put.raise_for_status()
            return {"id": new_ds_id, "name": new_name, "status": "CREATED_AND_MERGED"}

    @mcp.tool()
    async def update_data_selection_filters_tool(data_selection_id: str, new_filters: list[dict], ctx: Context) -> dict:
        \"\"\"
        A generic tool to cleanly add or modify specific filters in an existing Data Selection.
        new_filters should be a list of dicts: [{"columnName": "...", "values": ["..."], "component": "...", "operatorCode": "IN"}]
        \"\"\"
        import uuid
        logger.info("--- TOOL USED: update_data_selection_filters_tool (%s) ---", data_selection_id)
        token = await get_token(ctx)
        async with viya_session("update_ds_filters", ctx) as client:
            resp_get = await client.get(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{data_selection_id}", 
                headers={"Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_get.raise_for_status()
            ds_details = resp_get.json()
            etag = resp_get.headers.get("ETag", "")

            filter_criteria = ds_details.get("filterCriteria", {})
            if "0" not in filter_criteria:
                filter_criteria["0"] = []
            group_0 = filter_criteria["0"]

            for f_add in new_filters:
                match = next((f for f in group_0 if f["columnName"] == f_add["columnName"] and f.get("component") == f_add.get("component")), None)
                if match:
                    match["values"] = f_add.get("values", [])
                    match["operatorCode"] = f_add.get("operatorCode", "IN")
                else:
                    group_0.append({
                        "id": str(uuid.uuid4()),
                        "criteriaGroupId": data_selection_id,
                        "columnName": f_add["columnName"],
                        "operatorCode": f_add.get("operatorCode", "IN"),
                        "excludeFlag": False,
                        "componentTypeCode": f_add.get("component", "CLAIM"),
                        "component": f_add.get("component", "CLAIM"),
                        "filterAttributeId": f"{f_add['columnName']}_{f_add.get('component', 'CLAIM')}",
                        "groupId": "0",
                        "uiDisplay": False,
                        "values": f_add.get("values", [])
                    })
            ds_details["filterCriteria"] = filter_criteria
            
            resp_put = await client.put(
                f"{VIYA_ENDPOINT}/dataSelection/dataSelections/{data_selection_id}", 
                json=ds_details, 
                headers={"If-Match": etag, "Content-Type": "application/json", "Accept": "application/vnd.sas.data.selection+json"}
            )
            resp_put.raise_for_status()
            return {"id": data_selection_id, "status": "UPDATED"}

    @mcp.tool()
    async def get_alert_filters_tool(alert_row: dict, ctx: Context = None) -> dict:  # pyright: ignore
        \"\"\"
        Translates a specific row from an Emerging Issues alert table directly into the exact filterCriteria format needed for Data Selections.
        \"\"\"
        filters = []
        # Typically FQA uses PRIM_REPL_PART_CD on CLAIM, and MODEL_CD on PRODUCT.
        if "PRIM_REPL_PART_CD" in alert_row:
            filters.append({
                "columnName": "PRIM_REPL_PART_CD",
                "component": "CLAIM",
                "operatorCode": "IN",
                "values": [str(alert_row["PRIM_REPL_PART_CD"])]
            })
        if "MODEL_CD" in alert_row:
            filters.append({
                "columnName": "MODEL_CD",
                "component": "PRODUCT",
                "operatorCode": "IN",
                "values": [str(alert_row["MODEL_CD"])]
            })
        return {"filters": filters}

    @mcp.tool()
    async def get_analysis_execution_capabilities(analysis_id: str, ctx: Context) -> dict:
        \"\"\"
        Checks an Analysis object's modelName and returns whether it can actually be executed natively via the /jobs endpoint.
        \"\"\"
        logger.info("--- TOOL USED: get_analysis_execution_capabilities (%s) ---", analysis_id)
        token = await get_token(ctx)
        async with viya_session("get_capabilities", ctx) as client:
            resp = await client.get(
                f"{VIYA_ENDPOINT}/iotAnalysis/analyses/{analysis_id}", 
                headers={"Accept": "application/vnd.sas.iot.analysis+json"}
            )
            resp.raise_for_status()
            data = resp.json()
            model_name = data.get("modelName", "")
            
            if model_name == "EIENTERPRISE_PRODUCT":
                return {
                    "analysisId": analysis_id,
                    "modelName": model_name,
                    "runnable": False,
                    "reason": "This is a dummy bookmark object created by Analyze Alert. It cannot be run natively."
                }
            return {
                "analysisId": analysis_id,
                "modelName": model_name,
                "runnable": True
            }
"""

    # Insert before force_delete_fqa_object_tool
    insert_marker = "    @mcp.tool()\n    async def force_delete_fqa_object_tool"
    if insert_marker in content:
        content = content.replace(insert_marker, new_tools + "\n" + insert_marker)
    else:
        print("ERROR: Could not find insertion marker")
        return

    with open('src/sas_mcp_server/tools/iot.py', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    update_iot_py()
