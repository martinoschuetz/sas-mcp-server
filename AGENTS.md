# AGENTS.md — Universal Agent Instructions & Skill Catalog

This file follows the open `AGENTS.md` standard (supported by OpenAI Codex, Google Antigravity, Cursor, Windsurf, Goose, Amp, and GitHub Copilot) and mirrors [`CLAUDE.md`](./CLAUDE.md) and [`GEMINI.md`](./GEMINI.md).

## 1. Repository Development Rules
- **SAS Coding Standards & Performance**: Read [`knowledge/standards/sas.md`](./knowledge/standards/sas.md) for DATA step optimizations, `PROC FedSQL` usage in CAS, and macro best practices.
- **Python Concurrency & Architecture**: Read [`knowledge/standards/python.md`](./knowledge/standards/python.md) for async, structured concurrency, and HTTP client patterns.
- **Tool Tiers & Access Control**: All MCP tools live in `src/sas_mcp_server/tools/` (grouped into tiers `0`–`14`) and must be classified in `src/sas_mcp_server/tools/_access.py` as `READ_ONLY_TOOLS` or `WRITE_TOOLS`.
- **Testing**: Update tool counts in `tests/test_read_only.py` and `tests/test_tier_selection.py` whenever adding or removing MCP tools.

## 2. Installed Domain Skills (`knowledge/` & `.agents/skills/` & `.claude/skills/`)

Run `python scripts/install_agent_skills.py` to link all skills into your local and global agent directories (`.claude/skills`, `~/.claude/skills`, `.agents/skills`, `~/.agents/skills`, `~/.gemini/config/plugins/sas/skills`).

| Skill ID | Canonical Path | Key Playbooks | Trigger & Critical Domain Rules |
|---|---|---|---|
| **`sas-fqa`** | [`knowledge/fqa/`](./knowledge/fqa/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md`, `references/workflow.md`, `references/population-scoping.md`, `references/early-warning.md` | SAS Field Quality Analytics (FQA): Emerging Issues (Special Cause) & 7-step Common Cause screening, 3rd time dimension (Sales Lag Details Chart), Weibull $\beta$ CI overlap test, Data Selections across domains, and the 14 standard analyses. **Phase 3 Population Expansion Rule:** Always step back and widen the population before running *Text Mining* or *Failure Relationships* if Phase 2 narrowed to a small leaf where variables are fixed/pinned to 1 level. |
| **`sas-caf`** | [`knowledge/caf/`](./knowledge/caf/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | Custom Analysis Framework (CAF) in SAS Analytics for IoT: analysis type packages, `input.xml` parameter contracts, step scripts, and Visual Analytics report templatization. |
| **`sas-esp`** | [`knowledge/esp/`](./knowledge/esp/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md`, `references/kafka_connector.md`, `references/cas_adapter.md` | SAS Event Stream Processing (ESP): XML model rules, Kafka publisher connectors, Python window JSON flattening, CAS adapter subscribers, and ESP Studio REST API deployment. |
| **`sas-forecasting`** | [`knowledge/forecasting/`](./knowledge/forecasting/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | SAS Visual Forecasting & ATSM time-series forecasting pipelines, data definitions, filters, and model comparisons. |
| **`sas-api`** | [`knowledge/api/`](./knowledge/api/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | SAS Viya REST API conventions, pagination, media types, and endpoint discovery. |
| **`sas-core`** | [`knowledge/sas/`](./knowledge/sas/SKILL.md) | `SKILL.md`, `mcp_execution_rules.md` | General SAS 9 & SAS Viya coding best practices, CAS data management, machine learning, macros, and text analytics. |
| **`sas-standards`** | [`knowledge/standards/`](./knowledge/standards/SKILL.md) | `SKILL.md`, `sas.md`, `python.md` | Engineering standards for the SAS MCP Server codebase. |

## 3. Accessing Skills via MCP (For Remote / Non-Filesystem Agents)

If you are connected to `sas-mcp-server` as an MCP client without direct workspace file access:
1. Call `list_knowledge_domains()` to inspect all available skills and their trigger descriptions.
2. Call `read_knowledge_topic(domain="<domain>", topic="SKILL")` or `read_knowledge_topic(domain="<domain>", topic="mcp_execution_rules")` to load the domain playbook.
3. Call `search_knowledge(domain="<domain>", pattern="<keyword>")` to search across all references, manuals, and templates.
4. Or read the MCP resource URI `skill://<domain>` (e.g. `skill://fqa`).
