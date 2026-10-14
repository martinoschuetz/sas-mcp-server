"""Link SAS MCP Server knowledge skills into Claude Code, OpenAI Codex (.agents), and Antigravity (.gemini).

Usage:
    python scripts/install_agent_skills.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
KNOWLEDGE_DIR = REPO_ROOT / "knowledge"

# Map domain directory in knowledge/ -> standardized agent skill folder name
SKILL_MAP: dict[str, str] = {
    "fqa": "sas-fqa",
    "caf": "sas-caf",
    "esp": "sas-esp",
    "forecasting": "sas-forecasting",
    "api": "sas-api",
    "sas": "sas-core",
    "standards": "sas-standards",
}


def link_directory(target: Path, link_path: Path) -> str:
    """Create a directory junction (Windows) or symlink (POSIX) pointing link_path -> target."""
    link_path.parent.mkdir(parents=True, exist_ok=True)
    if link_path.exists() or link_path.is_symlink():
        try:
            if link_path.resolve() == target.resolve():
                return "already linked"
        except Exception:
            pass
        if link_path.is_symlink() or (os.name == "nt" and link_path.is_dir()):
            try:
                link_path.unlink()
            except OSError:
                if os.name == "nt":
                    subprocess.run(["cmd", "/c", "rmdir", str(link_path)], check=False, capture_output=True)
                else:
                    shutil.rmtree(link_path)

    if os.name == "nt":
        res = subprocess.run(
            ["cmd", "/c", "mklink", "/J", str(link_path), str(target)],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode == 0:
            return "junction created"
        shutil.copytree(target, link_path, dirs_exist_ok=True)
        return "copied (fallback)"
    else:
        link_path.symlink_to(target, target_is_directory=True)
        return "symlink created"


def main() -> int:
    home = Path.home()
    skill_roots = [
        ("Claude Code (Global ~/.claude/skills)", home / ".claude" / "skills"),
        ("Claude Code (Workspace .claude/skills)", REPO_ROOT / ".claude" / "skills"),
        ("Universal Agents / Codex (Global ~/.agents/skills)", home / ".agents" / "skills"),
        ("Universal Agents / Antigravity (Workspace .agents/skills)", REPO_ROOT / ".agents" / "skills"),
    ]

    print(f"Source knowledge directory: {KNOWLEDGE_DIR}")
    for label, root in skill_roots:
        print(f"\n[{label}] -> {root}")
        for domain, skill_name in SKILL_MAP.items():
            src = KNOWLEDGE_DIR / domain
            if not src.is_dir():
                continue
            dst = root / skill_name
            status = link_directory(src, dst)
            print(f"  - {skill_name:<18} -> {src.name:<12} ({status})")

    gemini_plugin_skills = home / ".gemini" / "config" / "plugins" / "sas" / "skills"
    print(f"\n[Antigravity Global Plugin] -> {gemini_plugin_skills}")
    status = link_directory(KNOWLEDGE_DIR, gemini_plugin_skills)
    print(f"  - sas plugin skills  -> knowledge/   ({status})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
