"""Deterministic single-folder CAF package builder and zero-drift validator.

Canonical CAF folder layout:
  - spec.json                         Clean registration, parameters, lookups, containers & SpEL interactions
  - steps/<STEP_ID>.sas               Background SAS compute code per step (UTF-8 LF, no XML escaping)
  - output/<STEP_ID>_vaoutput.template Visual Analytics BIRD XML output template per step
  - input/input_layer.xml             Generated pure UI/Input Layer XML (without embedded SAS code blobs)
  - input/input.xml                   Generated full CAF input.xml (packaged inside the ZIP)
  - <FOLDER_NAME>.zip                 Generated final deployable CAF archive (<MODEL_NAME>/input.xml + *.template)

Usage:
  python build_package.py
  python build_package.py --check
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path


def _ensure_caf_helpers():
    try:
        from sas_mcp_server.helpers import caf_helpers as caf

        return caf
    except ImportError:
        candidates = [
            Path(os.environ["SAS_MCP_SERVER_SRC"]) if "SAS_MCP_SERVER_SRC" in os.environ else None,
            Path(__file__).resolve().parents[2] / "src",
            Path(r"C:\Git\sas-mcp-server\src"),
        ]
        for cand in candidates:
            if cand and (cand / "sas_mcp_server" / "helpers" / "caf_helpers.py").exists():
                sys.path.insert(0, str(cand))
                from sas_mcp_server.helpers import caf_helpers as caf

                return caf
        raise


caf = _ensure_caf_helpers()


def hydrate_spec(folder: Path) -> tuple[dict, dict]:
    spec_path = folder / "spec.json"
    raw_spec = json.loads(spec_path.read_text(encoding="utf-8"))
    raw_spec.setdefault("zip_modified_at", raw_spec.get("modified_time", "0001-01-01T00:00:00Z"))
    hydrated = copy.deepcopy(raw_spec)
    ui_only = copy.deepcopy(raw_spec)

    for step_h, step_ui in zip(hydrated.get("steps", []), ui_only.get("steps", []), strict=True):
        step_id = step_h["id"]
        code_rel = step_h.pop("code_file", f"steps/{step_id}.sas")
        tmpl_rel = step_h.pop("vaoutput_template_file", f"output/{step_id}_vaoutput.template")
        step_ui.pop("code_file", None)
        step_ui.pop("vaoutput_template_file", None)

        code_path = folder / code_rel
        tmpl_path = folder / tmpl_rel
        if not code_path.exists():
            raise FileNotFoundError(f"Missing step SAS file for {step_id}: {code_path}")
        if not tmpl_path.exists():
            raise FileNotFoundError(f"Missing VA output template for {step_id}: {tmpl_path}")

        step_h["code"] = code_path.read_text(encoding="utf-8").replace("\r\n", "\n")
        step_h["vaoutput_template"] = tmpl_path.read_text(encoding="utf-8").replace("\r\n", "\n")
        step_ui["code"] = f"/* Stored in {code_rel} — edit that file and re-run build_package.py */"

    return hydrated, ui_only


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and validate a single-folder CAF package.")
    parser.add_argument("--check", action="store_true", help="Validate spec and verify outputs are in sync.")
    args = parser.parse_args()

    folder = Path(__file__).resolve().parent
    zip_name = f"{folder.name}.zip"
    hydrated, ui_only = hydrate_spec(folder)

    issues = caf.validate_spec(hydrated)
    errors = caf.blocking(issues)
    warnings = [i for i in issues if i not in errors]

    print(f"[CAF Validate] model={hydrated.get('name')} display_name={hydrated.get('display_name')!r}")
    print(f"[CAF Validate] blocking_errors={len(errors)}, warnings={len(warnings)}")
    for w in warnings:
        print(f"  WARN [{w.get('rule') or w.get('code') or 'lint'}]: {w.get('message')}")
    if errors:
        for e in errors:
            print(f"  ERROR [{e.get('rule') or e.get('code') or 'lint'}]: {e.get('message')}", file=sys.stderr)
        return 1

    full_input_xml = caf.render_input_xml(hydrated).replace("\r\n", "\n")
    ui_layer_xml = caf.render_input_xml(ui_only).replace("\r\n", "\n")
    zip_bytes, manifest = caf.build_package(hydrated)

    input_dir = folder / "input"
    full_xml_path = input_dir / "input.xml"
    ui_xml_path = input_dir / "input_layer.xml"
    zip_path = folder / zip_name

    if args.check:
        on_disk_full = (
            full_xml_path.read_text(encoding="utf-8").replace("\r\n", "\n")
            if full_xml_path.exists()
            else None
        )
        if on_disk_full != full_input_xml:
            print(f"DRIFT: {full_xml_path} is out of date. Re-run build_package.py.", file=sys.stderr)
            return 1
        on_disk_ui = (
            ui_xml_path.read_text(encoding="utf-8").replace("\r\n", "\n")
            if ui_xml_path.exists()
            else None
        )
        if on_disk_ui != ui_layer_xml:
            print(f"DRIFT: {ui_xml_path} is out of date. Re-run build_package.py.", file=sys.stderr)
            return 1
        if not zip_path.exists():
            print(f"MISSING: {zip_path}", file=sys.stderr)
            return 1
        pkg_on_disk = caf.read_package(zip_path.read_bytes())
        if pkg_on_disk["input_xml"].replace("\r\n", "\n") != full_input_xml:
            print(f"DRIFT: {zip_path} input.xml differs from hydrated spec.", file=sys.stderr)
            return 1
        print(f"[CAF Check] OK — {zip_path.name} ({zip_path.stat().st_size} bytes) is valid and in sync.")
        return 0

    input_dir.mkdir(parents=True, exist_ok=True)
    full_xml_path.write_text(full_input_xml, encoding="utf-8", newline="\n")
    ui_xml_path.write_text(ui_layer_xml, encoding="utf-8", newline="\n")
    zip_path.write_bytes(zip_bytes)

    print(f"[CAF Build] Wrote {ui_xml_path.relative_to(folder)} ({ui_xml_path.stat().st_size} bytes)")
    print(f"[CAF Build] Wrote {full_xml_path.relative_to(folder)} ({full_xml_path.stat().st_size} bytes)")
    print(f"[CAF Build] Wrote {zip_path.name} ({len(zip_bytes)} bytes) -> {manifest['files']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
