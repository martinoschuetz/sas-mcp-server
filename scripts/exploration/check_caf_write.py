"""Live write round trip for Tier 13, driven through the real MCP tools.

create -> confirm it is listed -> activate -> deactivate -> delete -> confirm gone.
Everything runs under one disposable name and the script deletes it on the way out
even if a step fails, so a half-finished run leaves nothing behind.

This is also what settles the one genuine unknown in the format work: the request
body type for POST /iotAnalysisModels/models is absent from the OpenAPI spec, so
upload_package attempts multipart and then a raw zip. The run prints which one the
service actually took.
"""

import asyncio
import json
import os
import sys

from fastmcp import Client, FastMCP

sys.path.insert(0, "src")

from sas_mcp_server.tools import caf as caf_tools  # noqa: E402

NAME = "ZZ_MCP_SMOKE_TEST"

SPEC = {
    "name": NAME,
    "display_name": "ZZ MCP smoke test (delete me)",
    "description": "Disposable type created by check_caf_write.py. Safe to delete.",
    "type": "CUSTOM",
    "key_group": "ASSET",
    "active": False,
    "steps": [
        {
            "id": f"{NAME}_STP_1",
            "display_name": "Select Data",
            "order": 1,
            "parameters": [
                {
                    "name": "p_rows",
                    "display_text": "Row limit",
                    "required": True,
                    "data_type": "String",
                    "display_control": "NUMERICSTEPPER",
                    "properties": {"min": "1", "max": "1000"},
                    "default_values": [{"key": "100", "value": "100"}],
                    "ui_group": {"tab": "BASIC", "tab_name": "Basic"},
                }
            ],
            "code": (
                "%afi_caf_loadmacros(/Products/SAS Analytics For IoT/CustomAnalyses/macros);\n"
                "%afi_caf_preprocess(?g_cas, ?analysisID);\n"
                "data work.SMOKE;\n"
                "  set &g_caslib..&g_input_table(obs=&g_p_rows);\n"
                "run;\n"
                "%let g_num_output_tables = 1;\n"
                "%let g_output_table_1 = work.SMOKE;\n"
                "%let g_num_output_vars = 0;\n"
                "%afi_caf_postprocess;\n"
            ),
        }
    ],
}


def show(label, result):
    print(f"\n--- {label}")
    print(json.dumps(result, indent=2, default=str)[:1500])


async def call(client, tool, **kwargs):
    res = await client.call_tool(tool, kwargs)
    return json.loads(res.content[0].text) if res.content else {}


async def main() -> None:
    token = json.load(open(os.path.expanduser("~/.sas-mcp-server/credentials.json")))["Default"][
        "access-token"
    ]

    mcp = FastMCP("caf-live")

    async def get_token(ctx):  # noqa: ARG001
        return token

    caf_tools.register(mcp, get_token)

    async with Client(mcp) as client:
        created = False
        try:
            res = await call(client, "create_analysis_type", spec=SPEC)
            show("create_analysis_type", res)
            created = res.get("status") == "ok"
            if not created:
                return

            listed = await call(client, "list_analysis_types", limit=1000)
            mine = [r for r in listed["analysis_types"] if r["name"] == NAME]
            show("listed after create", mine)

            show("get_analysis_type", await call(client, "get_analysis_type", name=NAME))

            exported = await call(client, "export_analysis_type", name=NAME)
            print("\n--- exported input.xml (round trips?)")
            print(exported["input_xml"][:300])
            print("template files:", exported["template_files"])

            show("activate", await call(client, "set_analysis_type_state", name=NAME, state="active"))
            show("deactivate", await call(client, "set_analysis_type_state", name=NAME, state="inactive"))
        finally:
            if created:
                show("delete_analysis_type", await call(client, "delete_analysis_type", name=NAME))
                listed = await call(client, "list_analysis_types", limit=1000)
                left = [r for r in listed["analysis_types"] if r["name"] == NAME]
                print(f"\nstill present after delete: {left or 'no — cleaned up'}")


asyncio.run(main())
