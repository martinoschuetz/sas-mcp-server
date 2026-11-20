# Cross-Agent Handoff & Live State Ledger (`_docs/HANDOFF.md`)

**Last Updated:** 2026-11-20 — **`sas-mcp-server` `main` AT `251` TOOLS (`115` READ-ONLY + `136` WRITE ACROSS `17` TIERS `0`–`16`), `sas-caf` `v2.1.0` & `sas-fqa` `v0.6.0` KNOWLEDGE PLAYBOOKS SYNCED, AND 22-SLIDE CORPORATE DECK `SAS_Viya_MCP_Server.pptx` + `scripts/presentation/` REBUILT ACROSS ALL 6 ECOSYSTEM REPOSITORIES.**
**Last Active Agent Platform:** Google Gemini / Antigravity (2026-11-20)
**Next Agent Platform:** Claude Code **or** Google Gemini / Antigravity (interchangeable)

> **Protocol for All Agents (Claude, Gemini, Cursor, Codex):**
> 1. **On Session Start:** Read this file (`_docs/HANDOFF.md`), [`AGENTS.md`](../AGENTS.md), and [`CHANGELOG.md`](../CHANGELOG.md) before modifying tools, skills, or docs.
> 2. **Before Ending a Session or Switching Platforms:** Update sections **1 (Current State)**, **4 (Completed Work Log)**, and **5 (Next Actionable Steps)** so the next agent resumes with zero context loss.

---

## 1. Current Repository & Deployment State

### 1.1 Git, Versioning & Tool Counts
- **Repository:** `C:\Git\sas-mcp-server` (`origin`: `https://github.com/martinoschuetz/sas-mcp-server.git`, branch `main`; `david` / `upstream-local`: `C:\Git\David\sas-mcp-server`).
- **Package Version (`pyproject.toml`):** `1.20.2` (+ `Unreleased` additions on `main`).
- **Registered Tool Surface (`src/sas_mcp_server/tools/` & `_access.py`):**
  - **Total Registered Tools:** **`251`** across **`17` selectable tiers (`0`–`16`)**
    - **Tiers `0`–`11` (Upstream `sassoftware/sas-mcp-server` Core):** **`137` tools** + **`9` Prompt Templates** + **`10` MCP Apps interactive HTML views** (`query_data`, `get_castable_data`, `get_compute_table_data`, `execute_sas_code`, `get_job_log`, `submit_batch_job`, `get_glossary_term_type`, `get_glossary_term`, `list_glossary_terms`, `import_glossary_terms`).
    - **Tiers `12`–`16` (Solution Extensions):** **`114` tools** (`Tier 12`: IoT, FQA & Visual Forecasting; `Tier 13`: GenAI; `Tier 14`: SAS ESP; `Tier 15`: 14 Custom Analysis Framework tools; `Tier 16`: 3 Dynamic Knowledge Engine tools + `skill://{domain}` MCP resources).
  - **Fail-Closed Access Partition (`MCP_READ_ONLY`):** **`115` `READ_ONLY_TOOLS`** and **`136` `WRITE_TOOLS`** (enforced by `tests/test_read_only.py`).
- **Local OpenAPI Spec Vault (`docs/APIs/`, git-ignored):** **`333` YAML specifications** across 14 SAS Viya categories harvested via `scripts/download_specs.py`.
- **Live SAS RAM Container (`sas-mcp-server-msz`):**
  - Tool Server UUID `7055470e-3a8d-4a94-906e-4316919f15d7` on `https://ram-events.eastus.cloudapp.azure.com/SASRetrievalAgentManager` running image tag **`v1.20.2`** (`249` tools; the 2 newest read-only picklist tools `list_data_selection_attributes_tool` and `get_filter_attribute_values_tool` on `main` will go live on RAM upon building `v1.20.3`).

---

## 2. Installed Domain Skillsets (`knowledge/`)

Link all 7 skills into `.claude/skills`, `~/.claude/skills`, `.agents/skills`, `~/.agents/skills`, and `~/.gemini/config/plugins/sas/skills` via:
```powershell
python scripts/install_agent_skills.py
```

| Domain | Skill ID & Version | Key Assets | Recent Highlights |
| :--- | :--- | :--- | :--- |
| `knowledge/caf/` | **`sas-caf` `v2.1.0`** | `SKILL.md`, `mcp_execution_rules.md`, 7 `references/*.md`, `templates/build_package.py`, `evals/evals.json` | 13 live Viya rules (`RESOLVEONUI="true"` strictly on `STABLEPERIOD`, empty `<Condition>`, `<=32`-char CRC32 `QASAnlOut` + `remACs=true`, Rule 11 BIRD `<SeriesPlot>` & `55×–207×` visual table compression). |
| `knowledge/fqa/` | **`sas-fqa` `v0.6.0`** | `SKILL.md`, `mcp_execution_rules.md`, 18 `references/*.md`, `templates/fedsql/` | Added `standard-models-caf.md` (all 17 `STANDARD`/`ALERTS` contracts) and `object-lifecycle-and-api-traps.md` (11-col Launchers, `/copy` `EIENTERPRISE` rules, `@myFolder` ACLs, 423 waits). |
| `knowledge/esp/` | **`sas-esp`** | `SKILL.md`, `mcp_execution_rules.md`, 6 `references/*.md` | Confluent Kafka `opaquestring` + `disableespmetaconsumer=true`, Python EAV flattening, `dfesp_cas_adapter` `commitblocks`, ESP Studio v4 REST XML deploy. |
| `knowledge/forecasting/` | **`sas-forecasting`** | `SKILL.md`, `mcp_execution_rules.md` | Hybrid `ATSM` + `EXTLANG` + `MP-CONNECT` forecasting, Borda `SUM_rk` vs. `SNAIVE` `FVA`, and `MinT` reconciliation. |
| `knowledge/api/` | **`sas-api`** | `SKILL.md`, `mcp_execution_rules.md` | SAS Viya REST pagination, vendor media types, `If-Match` ETags, and OAuth2/JWKS rules. |
| `knowledge/sas/` | **`sas-core`** | `SKILL.md`, `mcp_execution_rules.md`, sub-skills | SAS 9 & Viya DATA step, `PROC FedSQL` in CAS, macros, Viya single-node deployment, ML, text analytics. |
| `knowledge/standards/` | **`sas-standards`** | `SKILL.md`, `sas.md`, `python.md` | Async structured concurrency (`httpx`, `anyio`) and SAS performance standards. |

---

## 3. Connected Solution Repositories (Ecosystem Overview)

| Workstream | Local Path | Current State (2026-11-20) |
| :--- | :--- | :--- |
| **1. Core Viya MCP Server & Skills** | `C:\Git\sas-mcp-server` | `251` tools (`115` read + `136` write), `sas-caf` `v2.1.0`, `sas-fqa` `v0.6.0`, `SAS_Viya_MCP_Server.pptx` (22 slides). |
| **2a. Headless SAS RAM MCP Server** | `C:\Git\Manfred\ram-mcp-server` (branch `germsz`) | `63` tools on `:8135`, Keycloak `offline_access` + 30-day keepalive, `run-evals.mjs`. |
| **2b. Production FQA Agent on RAM** | `C:\Git\Manfred\FQA` (branch `germsz`) | Champion `fqa-2h-msz` running Template **`v40`** (`3f-msz`, `fqa-agent==2.22.0`), `47` intents, `71` governed tools (`31` read + `40` write), `558` unit tests, `4.8/5.0` 5-persona SME Certification. |
| **3. AIoT Custom Analysis Factory (CAF)** | `C:\Git\martinoschuetz\AIoT\custom_analysis` | **`18` live single-folder CAFs** (`0` SAS errors): **`12` `ASSET` Anomaly CAFs** (incl. 4-step 8-engine `ANOMALY_ENSEMBLE` with `POT-GPD`, `CoMuT`, & Step 4 `SSDO` `-53.6%` false alarms) + **`6` `PRODUCT` FQA CAFs** (`FQA_RF_DRIVERS`, `FQA_SUBGROUP_RULES`, `FQA_COMMON_CAUSE`, `FQA_SURVIVAL_COX`, `FQA_LAUNCH_CAPA`, `FQA_PRECURSOR_LINK`). |
| **4. SAS Optimizer for IoT** | `C:\Git\martinoschuetz\IOT\AIoT_Optimizer` (`feat/optimizer-for-iot-ui-rework`) | Rebranded `/Products/SAS Optimizer For IoT` (`45/62` WPs `DONE`): `AIOT_META`, 7-pillar DQ (`97.5`), `network.clique`, 4-learner `UniMeMo` Wilcoxon tournament, `163×` faster (`~1.5s`/shift) `PROC FCMP` + `PROC OPTLSO` solver, 5-Report VA + React 19 cockpit. |
| **5. SAS ESP Streaming Chains** | `C:\Git\martinoschuetz\projects\CandF` & `Qatar_Cool` | `CandF_UNS_BMC2.xml` (`90,635` rows in `PUBLIC.BMC_RAW`, dual-clock & hysteresis ABT audit) + `Qatar_Cool` (`30` assets, `31.52M` APA rows + real-time `dcs_chiller` SVDD ASTORE & `dcs_ct` → 4 Grafana boards). |
| **6. SAS Visual Forecasting** | `C:\Git\martinoschuetz\Forecasting` | 11-stage (`00_setup_cas` → `70_stability`) 3-tier `ATSM` + `EXTLANG` + `MP-CONNECT` tournament (`pricedata`, `m5_subset`, `m5_full`), 9-metric Borda `SUM_rk`, Cross-Sectional & Cross-Temporal `MinT`, `unified_report.html`. |

---

## 4. Completed Work Log (`2026-11-17` – `2026-11-20`)

1. **`v1.20.2` Release & Tier 12/15 Lifecycle Expansion (`a9bb619` .. `c4aa727`):**
   - Added standalone `create_data_selection_tool`, Launcher CRUD (`list_launchers_tool`, `get_launcher_details_tool`, `delete_launcher_tool`), folder member tools (`add_folder_member_tool`, `remove_folder_member_tool`, `delete_folder_tool(recursive)`), paged/filtered `list_iot_analyses_tool`, `launch_app_name`, CAF `If-Match` ETag `PUT` updates, and `steps[0]` parameter persistence.
2. **`sas-caf` `v2.1.0` & `sas-fqa` `v0.6.0` Playbooks + Filter Picklist Tools (`6c9ed5e`, `38b75f4`, `7b60bea`):**
   - Codified live Viya CAF and FQA REST/UI/BIRD rules in `knowledge/caf/` and `knowledge/fqa/`, and added `list_data_selection_attributes_tool` + `get_filter_attribute_values_tool` (`251` total tools, `115` read-only).
3. **22-Slide SAS Corporate Presentation & Documentation Sync (`2026-11-20`):**
   - Rebuilt [`SAS_Viya_MCP_Server.pptx`](../SAS_Viya_MCP_Server.pptx) (preserving exact `SAS-2023` Slide Master, `Anova Bold`/`Anova Light` inherited fonts, native White/Light-Blue Title & Closing contrast, embedded `FQA_MCP_Marketing.mp4`, and 17 high-DPI Mermaid diagrams) with reproducible builders in [`scripts/presentation/`](../scripts/presentation/).
   - Synchronized `README.md`, `CHANGELOG.md`, `.env.sample`, `deploy/K8S-DEPLOYMENT.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, and `_docs/HANDOFF.md`.

---

## 5. Next Actionable Steps

1. **Bump SAS RAM Container (`v1.20.3`):** Build and push the next `sas-mcp-server-msz` container image to SAS RAM (`C:\Git\Manfred\FQA\ram\scripts\tool-server.mjs`) when ready to expose `list_data_selection_attributes_tool` and `get_filter_attribute_values_tool` (`251` tools) to `FQA_msz`.
2. **Tier 12 & Tier 15 Integration Test Coverage:** Expand `tests/test_integration.py` coverage map across the remaining 49 solution tools in Tiers 12 and 15 so `test_every_tool_has_integration_coverage` passes on live Viya runs.
3. **Monthly OpenAPI Refresh (`2026.11`):** Run `python scripts/download_specs.py --force` once SAS Viya Stable `2026.11` specs publish on `developer.sas.com` and verify `COMPATIBILITY.md`.
