---
trigger: always_on
---

# SAS MCP Server Development Context

Welcome to the SAS MCP Server project!
When developing in this project, adhere to the following standards and guidelines:

- **Cross-Agent Handoff Ledger**: Read [`_docs/HANDOFF.md`](./_docs/HANDOFF.md) and [`AGENTS.md`](./AGENTS.md) on session start and update `_docs/HANDOFF.md` before finishing significant work so Claude Code and Antigravity/Gemini stay synchronized.
- **SAS Coding Standards & Performance**: See `knowledge/standards/sas.md` for our canonical guide on DATA step optimizations, `PROC FedSQL` usage in CAS, and macro best practices.
- **Python Development**: See `knowledge/standards/python.md` for our async, structured concurrency, and performance patterns.
- **Tool Development (`251` Tools = `115` Read-Only + `136` Write)**: All tools are grouped into 17 tiers (`0`–`16`: `137` core + `114` solution tools). When creating new tools, add them to the appropriate tier module in `src/sas_mcp_server/tools/` and classify them in `src/sas_mcp_server/tools/_access.py` as `READ_ONLY_TOOLS` or `WRITE_TOOLS`.
- **Domain Skill Playbooks (`knowledge/`)**: Keep `knowledge/caf` (`v2.1.0`), `knowledge/fqa` (`v0.6.0`), `knowledge/esp`, `knowledge/forecasting`, `knowledge/api`, `knowledge/sas`, and `knowledge/standards` synced via `python scripts/install_agent_skills.py`.
- **Testing**: Run `uv run --no-sync python -m pytest -m "not integration"` and keep `tests/test_read_only.py` and `tests/test_tier_selection.py` passing.

These context rules apply globally to this repository and are loaded automatically by Antigravity (no `-c` flag needed).
