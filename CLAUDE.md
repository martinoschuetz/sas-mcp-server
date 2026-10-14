# SAS MCP Server & Domain Skills Context (Claude Code / Claude Desktop)

Welcome to the SAS MCP Server project!
When developing in this project or acting as a SAS Viya / Analytics for IoT domain agent, adhere to the following standards and skill playbooks.

## Core Architectural Guidelines
- **Tool Development**: All tools are grouped into tiers (`0`–`14`). When creating new tools, add them to the appropriate tier module in `src/sas_mcp_server/tools/` and classify them correctly in `src/sas_mcp_server/tools/_access.py` as `READ_ONLY_TOOLS` or `WRITE_TOOLS`.
- **Testing**: Ensure that tool counts are updated in `tests/test_read_only.py` and `tests/test_tier_selection.py` when adding new tools.

## Agent Skills & Domain Playbooks (Extremely Important)

All domain skills live canonically in `knowledge/<domain>/` and are linked into `.claude/skills/`, `~/.claude/skills/`, `.agents/skills/`, and `~/.gemini/config/plugins/sas/skills/` (via `python scripts/install_agent_skills.py`). **Consult the relevant skill's `SKILL.md` and `mcp_execution_rules.md` before executing tools or writing code:**

| Skill Name | Domain Folder | Primary Entry Points | When to Activate |
|---|---|---|---|
| **`sas-fqa`** | `knowledge/fqa/` | `SKILL.md`, `mcp_execution_rules.md`, `references/workflow.md`, `references/population-scoping.md` | Investigating warranty/field-quality issues, Emerging Issues / On Demand / Threshold alerts, Common Cause vs. Special Cause screening, Data Selections across domains (`CLAIM`, `LABOR`, `PART`, `SSD`, `DTC`), or running the 14 FQA analyses. **Critical Phase 3 Rule:** Always widen the population before running *Text Mining* or *Failure Relationships* if Phase 2 narrowed to a small leaf where variables are fixed/pinned to 1 level. |
| **`sas-caf`** | `knowledge/caf/` | `SKILL.md`, `mcp_execution_rules.md` | Building, validating, packaging, or templatizing Custom Analysis Framework (CAF) analysis types and VA report templates in SAS Analytics for IoT. |
| **`sas-esp`** | `knowledge/esp/` | `SKILL.md`, `mcp_execution_rules.md`, `references/kafka_connector.md`, `references/cas_adapter.md` | Building, deploying, or debugging SAS Event Stream Processing (ESP) XML projects, Kafka connectors, Python windows, and CAS subscribers (`esp_deploy_project`, `esp_get_project_xml`, `esp_delete_project`). |
| **`sas-forecasting`** | `knowledge/forecasting/` | `SKILL.md`, `mcp_execution_rules.md` | Running time-series forecasting pipelines, ATSM / VF modeling, data definitions, and hierarchical forecasting on SAS Viya. |
| **`sas-api`** | `knowledge/api/` | `SKILL.md`, `mcp_execution_rules.md` | Making direct REST API calls to SAS Viya microservices, pagination, media types, and OAuth token handling. |
| **`sas-core`** | `knowledge/sas/` | `SKILL.md`, `mcp_execution_rules.md` | Writing high-performance SAS DATA steps, PROC FedSQL in CAS, macros, Viya administration, ML, and text analytics. |
| **`sas-standards`** | `knowledge/standards/` | `SKILL.md`, `sas.md`, `python.md` | Python async/structured concurrency patterns (`asyncio.TaskGroup`, `httpx`) and SAS coding standards for this repository. |

## How Any Agent System Can Access These Skills

1. **Claude Code (Local / IDE / CLI)**:
   - Skills are automatically discovered from `.claude/skills/<skill-name>/SKILL.md` (workspace) and `~/.claude/skills/<skill-name>/SKILL.md` (global).
2. **OpenAI Codex / Cursor / Windsurf / Goose / Antigravity**:
   - Skills are automatically discovered from `.agents/skills/<skill-name>/SKILL.md`, `~/.agents/skills/<skill-name>/SKILL.md`, and `AGENTS.md`.
3. **Any Remote MCP Client (Claude Desktop, Custom Agents, Copilot Studio, LibreChat)**:
   - Even without local filesystem access, any MCP client connected to `sas-mcp-server` can discover and read all skills dynamically using:
     - `list_knowledge_domains()` — returns all domains with their `SKILL.md` name and trigger description.
     - `read_knowledge_topic(domain="fqa", topic="SKILL")` or `read_knowledge_topic(domain="fqa", topic="references/population-scoping")`.
     - `search_knowledge(domain="fqa", pattern="Phase 3")`.
     - MCP Resource URI: `skill://{domain}` (e.g., `skill://fqa`, `skill://esp`, `skill://caf`, `skill://forecasting`).

