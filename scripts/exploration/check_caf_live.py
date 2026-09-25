"""Read-path sweep: export every analysis type the live deployment ships and run
each one through the CAF parser, renderer and validator.

The offline corpus is 34 packages that someone chose to save. The deployment is
the real population, and it is where the BATCH key group turned up. Nothing here
writes.
"""

import asyncio
import json
import os
import sys

import httpx

sys.path.insert(0, "src")

from sas_mcp_server.helpers import caf_helpers as caf  # noqa: E402

BASE = "https://iot.viya-azure-gpu.unx.sas.com"
MODELS = f"{BASE}/iotAnalysisModels/models"


async def main() -> None:
    token = json.load(open(os.path.expanduser("~/.sas-mcp-server/credentials.json")))["Default"][
        "access-token"
    ]
    auth = {"Authorization": f"Bearer {token}"}
    async with httpx.AsyncClient(verify=False, timeout=120) as client:
        res = await client.get(f"{MODELS}?limit=1000", headers=auth)
        res.raise_for_status()
        items = res.json().get("items", [])
        print(f"{len(items)} analysis types on {BASE}\n")

        ok = bad = failed = 0
        for m in sorted(items, key=lambda i: i.get("name") or ""):
            name = m.get("name")
            try:
                zres = await client.get(
                    f"{MODELS}/{name}", headers={**auth, "Accept": "application/zip"}
                )
                zres.raise_for_status()
                pkg = caf.read_package(zres.content)
                spec = pkg["spec"]
                # the round trip: parse -> render -> parse again must be stable
                again = caf.parse_input_xml(caf.render_input_xml(spec))
                stable = [s["id"] for s in again["steps"]] == [s["id"] for s in spec["steps"]]
                errors = caf.blocking(caf.validate_spec(spec))
            except Exception as exc:  # noqa: BLE001
                failed += 1
                print(f"  FAIL  {name}: {type(exc).__name__}: {exc}")
                continue
            if errors or not stable:
                bad += 1
                print(f"  ERR   {name} ({m.get('analysisType')}/{m.get('domainGroup')})"
                      f"{'  [round trip unstable]' if not stable else ''}")
                for e in errors[:6]:
                    print(f"          {e['message']}")
            else:
                ok += 1

        print(f"\nvalid {ok}   with errors {bad}   unreadable {failed}")


asyncio.run(main())
