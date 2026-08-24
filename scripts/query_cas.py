import asyncio
import os
import sys

sys.path.insert(0, r"c:\Git\sas-mcp-server\src")
os.chdir(r"c:\Git\sas-mcp-server")

from sas_mcp_server.stdio_server import _get_viya_token
from sas_mcp_server.viya_utils import _get_json, _make_client


async def main():
    try:
        token = _get_viya_token()
    except Exception as e:
        print(f"Failed to get token: {e}")
        return

    async with _make_client(token) as client:
        # 1. Get all caslibs
        caslibs_url = "/casManagement/servers/cas-shared-default/caslibs"
        try:
            caslibs_resp = await _get_json(caslibs_url, client, accept="application/vnd.sas.collection+json")
            caslibs = [item.get("name") for item in caslibs_resp.get("items", [])]
            print(f"Found caslibs: {caslibs}")
            
            # 2. Search tables in each caslib
            found_tables = []
            for caslib in caslibs:
                tables_url = f"/casManagement/servers/cas-shared-default/caslibs/{caslib}/tables"
                try:
                    tables_resp = await _get_json(tables_url, client, params={"limit": 500}, accept="application/vnd.sas.collection+json")
                    for table in tables_resp.get("items", []):
                        name = table.get("name", "")
                        if "EIENTERPRISE" in name or "5F8F11A8" in name:
                            print(f"MATCH: {name} in {caslib}")
                            found_tables.append((caslib, name))
                except Exception:
                    pass
            
            if not found_tables:
                print("No EIENTERPRISE output tables found in any caslib.")
                return
                
            # 3. For each found table, fetch rows
            for caslib, table_name in found_tables:
                # We are looking for alerts. Typically the table ending in _OUTPUT_VIEW or similar has alerts,
                # or a table containing scores.
                print(f"\n--- Rows from {table_name} in {caslib} ---")
                rows_url = f"/casRowSets/tables/cas-shared-default~{caslib}~{table_name}/rows"
                try:
                    rows_resp = await _get_json(rows_url, client, params={"limit": 1000}, accept="application/vnd.sas.row.set+json")
                    schema = [col.get("name") for col in rows_resp.get("schema", [])]
                    print(f"Columns: {schema}")
                    rows = rows_resp.get("rows", [])
                    print(f"Total rows retrieved: {len(rows)}")
                    
                    # We want to find the alert with the highest score.
                    # Let's inspect column names for "score" or similar (case-insensitive).
                    score_col = None
                    for col in schema:
                        if "score" in col.lower():
                            score_col = col
                            break
                            
                    if score_col:
                        print(f"Using score column: {score_col}")
                        # Filter rows that represent alerts or just find the row with max score.
                        valid_rows = []
                        score_idx = schema.index(score_col)
                        for r in rows:
                            val = r[score_idx]
                            try:
                                if val is not None:
                                    valid_rows.append((float(val), r))
                            except ValueError:
                                pass
                        if valid_rows:
                            valid_rows.sort(key=lambda x: x[0], reverse=True)
                            print("\nTop 5 rows by score:")
                            for i, (score, r) in enumerate(valid_rows[:5]):
                                print(f"Rank {i+1} (Score: {score}): {dict(zip(schema, r))}")
                        else:
                            print("No valid numeric scores found.")
                    else:
                        print("No score column found in table schema.")
                        # Print first 5 rows to inspect
                        for i, r in enumerate(rows[:5]):
                            print(f"Row {i+1}: {dict(zip(schema, r))}")
                except Exception as ex:
                    print(f"Error fetching rows: {ex}")
                    
        except Exception as e:
            print(f"Failed: {e}")

if __name__ == "__main__":
    asyncio.run(main())
