# AGENTS.md — Universal Agent Instructions & Skill Catalog

This file follows the open `AGENTS.md` standard (supported by OpenAI Codex, Google Antigravity, Cursor, Windsurf, Goose, Amp, and GitHub Copilot) and mirrors [`CLAUDE.md`](./CLAUDE.md) and [`GEMINI.md`](./GEMINI.md).

> **Cross-Agent Continuity Protocol:** On session start (and before ending a session or switching between Claude Code and Google Antigravity/Gemini), read and update [`_docs/HANDOFF.md`](./_docs/HANDOFF.md) for current tool counts, container deployment tags, skill versions, and next actionable steps.

## 1. Repository Development Rules
- **SAS Coding Standards & Performance**: Read [`knowledge/standards/sas.md`](./knowledge/standards/sas.md) for DATA step optimizations, `PROC FedSQL` usage in CAS, and macro best practices.
- **Python Concurrency & Architecture**: Read [`knowledge/standards/python.md`](./knowledge/standards/python.md) for async, structured concurrency, and HTTP client patterns.
- **Tool Tiers & Access Control (`251` Tools = `115` Read-Only + `136` Write)**: All MCP tools live in `src/sas_mcp_server/tools/` (grouped into 17 tiers `0`–`16`: `137` upstream core tools in `0`–`11` + `114` solution tools in `12`–`16`) and must be classified in `src/sas_mcp_server/tools/_access.py` as `READ_ONLY_TOOLS` or `WRITE_TOOLS` (fail-closed).
- **Testing**: Run `uv run --no-sync python -m pytest -m "not integration"` and update tool counts/classifications in `src/sas_mcp_server/tools/_access.py`, `tests/test_read_only.py`, and `tests/test_tier_selection.py` whenever adding or removing MCP tools.

## 2. Installed Domain Skills (`knowledge/` & `.agents/skills/` & `.claude/skills/`)

Run `python scripts/install_agent_skills.py` to link all skills into your local and global agent directories (`.claude/skills`, `~/.claude/skills`, `.agents/skills`, `~/.agents/skills`, `~/.gemini/config/plugins/sas/skills`).

| Skill ID | Canonical Path | Key Playbooks & References | Trigger & Critical Domain Rules |
|---|---|---|---|
| **`sas-fqa`** (`v0.6.0`) | [`knowledge/fqa/`](./knowledge/fqa/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md`, `references/workflow.md`, `references/population-scoping.md`, `references/early-warning.md`, `references/standard-models-caf.md`, `references/object-lifecycle-and-api-traps.md` (18 guides) | SAS Field Quality Analytics (FQA): Emerging Issues (Special Cause) & 4-Quadrant Common Cause screening, 3rd time dimension (Sales Lag `C_ijk`), Weibull $\beta$ CI overlap test, Data Selections/Launchers/Picklists across domains, and all 14 `STANDARD` + 3 `ALERTS` analyses. **Phase 3 Population Expansion Rule:** Always widen the population before running *Text Mining* or *Failure Relationships* if Phase 2 narrowed to a small leaf where variables are fixed/pinned to 1 level. |
| **`sas-caf`** (`v2.1.0`) | [`knowledge/caf/`](./knowledge/caf/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md`, `references/{aiot_platform_and_etl,anomaly_caf_design_and_patterns,ui_lookups_and_interactions,sas_cas_plumbing,va_output_templates,troubleshooting,case_study_isolation_forest}.md`, `templates/build_package.py` | Custom Analysis Framework (CAF) in SAS Analytics for IoT (`ASSET` & `PRODUCT` KeyGroups): single-folder `spec.json` + `steps/*.sas` packages, `RESOLVEONUI="true"` strictly on `STABLEPERIOD`, `<=32`-char CRC32 `QASAnlOut` tables, Rule 11 BIRD XML `<SeriesPlot>` + `55×–207×` VA row compression, and `If-Match` ETag deployment. |
| **`sas-esp`** | [`knowledge/esp/`](./knowledge/esp/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md`, `references/{kafka_connector,python_window,cas_adapter,esp_studio_rest_api,troubleshooting,case_study_candf_bioreactor}.md` | SAS Event Stream Processing (ESP): XML model rules, Confluent Kafka `opaquestring` publishers, Python window JSON flattening, `dfesp_cas_adapter` subscribers, and ESP Studio v4 REST API deployment. |
| **`sas-forecasting`** | [`knowledge/forecasting/`](./knowledge/forecasting/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | SAS Visual Forecasting & hybrid `ATSM` / `EXTLANG` / `MP-CONNECT` time-series pipelines, data definitions, filters, Borda ranking, and `MinT` reconciliation. |
| **`sas-api`** | [`knowledge/api/`](./knowledge/api/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | SAS Viya REST API conventions, pagination, vendor media types, `If-Match` ETags, and OpenAPI spec discovery (`docs/APIs/` via `scripts/download_specs.py`). |
| **`sas-core`** | [`knowledge/sas/`](./knowledge/sas/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | General SAS 9 & SAS Viya coding best practices, CAS data management, machine learning, macros, Viya deployment, and text analytics. |
| **`sas-standards`** | [`knowledge/standards/`](./knowledge/standards/SKILL.md) | `SKILL.md`, `sas.md`, `python.md` | Engineering standards for the SAS MCP Server codebase. |

## 3. Accessing Skills via MCP (For Remote / Non-Filesystem Agents)

If you are connected to `sas-mcp-server` as an MCP client without direct workspace file access:
1. Call `list_knowledge_domains()` to inspect all available skills and their trigger descriptions.
2. Call `read_knowledge_topic(domain="<domain>", topic="SKILL")` or `read_knowledge_topic(domain="<domain>", topic="mcp_execution_rules")` to load the domain playbook.
3. Call `search_knowledge(domain="<domain>", pattern="<keyword>")` to search across all references, manuals, and templates.
4. Or read the MCP resource URI `skill://<domain>` (e.g. `skill://fqa`, `skill://caf`).
