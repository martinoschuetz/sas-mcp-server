# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
"""Vendor the MCP Apps browser bridge into ``sas_mcp_server/ui/vendor``.

The interactive views are plain HTML that the MCP host renders in a sandboxed
iframe. They talk to the host through ``@modelcontextprotocol/ext-apps`` — the
official browser SDK — which has to be *inside* the HTML: hosts build the
iframe's Content-Security-Policy from what the server declares, and at least
one (Claude.ai) ignores those declarations and allows only inline scripts, so a
``<script src="https://cdn...">`` renders as a blank box there. Inlining also
keeps the views working on an air-gapped Viya.

The package publishes an ESM bundle. An inline ``<script type="module">`` may
contain ``export`` statements, but nothing can import from an inline module,
so the trailing ``export { ... }`` is rewritten into a single global —
``globalThis.__MCP_EXT_APPS__`` — that the view shell reads ``App`` from.
Everything else in the bundle is untouched.

Run from the repository root::

    uv run python scripts/vendor_ext_apps.py 1.7.5

and commit the result. The version is pinned in the generated header so a
reviewer can see which bundle a diff came from.
"""

from __future__ import annotations

import io
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

PACKAGE = "@modelcontextprotocol/ext-apps"
BUNDLE = "package/dist/src/app-with-deps.js"
LICENSE = "package/LICENSE"
TARGET = Path(__file__).resolve().parents[1] / "src" / "sas_mcp_server" / "ui" / "vendor"

_EXPORT_BLOCK = re.compile(r"export\s*\{(?P<names>[^}]*)\}\s*;?\s*$")


def rewrite_exports(source: str) -> str:
    """Turn the bundle's trailing ``export {a as B, ...}`` into a global."""
    match = _EXPORT_BLOCK.search(source)
    if match is None:
        raise SystemExit("bundle has no trailing export block; the format changed")
    pairs: list[str] = []
    for entry in match.group("names").split(","):
        entry = entry.strip()
        if not entry:
            continue
        local, _, public = entry.partition(" as ")
        pairs.append(f"{(public or local).strip()}:{local.strip()}")
    return source[: match.start()] + "globalThis.__MCP_EXT_APPS__={" + ",".join(pairs) + "};\n"


def main(version: str) -> None:
    url = f"https://registry.npmjs.org/{PACKAGE}/-/ext-apps-{version}.tgz"
    print(f"fetching {url}")
    with urllib.request.urlopen(url) as response:  # noqa: S310 - fixed registry host
        archive = response.read()
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        bundle = tar.extractfile(BUNDLE)
        licence = tar.extractfile(LICENSE)
        if bundle is None or licence is None:
            raise SystemExit("tarball layout changed; bundle or LICENSE not found")
        source = bundle.read().decode("utf-8")
        licence_text = licence.read().decode("utf-8")

    header = (
        f"/* {PACKAGE}@{version} — app-with-deps.js, vendored by scripts/vendor_ext_apps.py.\n"
        f"   Licence: see ext-apps.LICENSE beside this file. The only change is the\n"
        f"   trailing export block, rewritten to globalThis.__MCP_EXT_APPS__. */\n"
    )
    TARGET.mkdir(parents=True, exist_ok=True)
    (TARGET / "ext-apps.js").write_text(header + rewrite_exports(source), encoding="utf-8", newline="\n")
    (TARGET / "ext-apps.LICENSE").write_text(licence_text, encoding="utf-8", newline="\n")
    (TARGET / "VERSION").write_text(version + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {TARGET / 'ext-apps.js'} ({len(source):,} bytes) at version {version}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: vendor_ext_apps.py <version>")
    main(sys.argv[1])
