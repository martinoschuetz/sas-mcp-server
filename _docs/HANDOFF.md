# Cross-Agent Handoff & Live State Ledger (`_docs/HANDOFF.md`)

**Last Updated:** 2026-11-25 — **ALIGNED TO UPSTREAM `sas-mcp-server` `v1.22.0` (`251` TOOLS = `115` READ-ONLY + `136` WRITE ACROSS `17` TIERS `0`–`16`, `12` MCP APPS INTERACTIVE VIEWS, `1,484` UNIT TESTS PASS AT `93.23%` COVERAGE, `0` PYRIGHT/RUFF ERRORS, LIVE VIYA SMOKE VERIFIED, AND `sasram.azurecr.io/sas-mcp-server-msz` PURGED & REBUILT EXCLUSIVELY AS `:v1.22.0`).**
**Last Active Agent Platform:** Google Gemini / Antigravity (2026-11-25)
**Next Agent Platform:** Claude Code **or** Google Gemini / Antigravity (interchangeable)

> **Protocol for All Agents (Claude, Gemini, Cursor, Codex):**
> 1. **On Session Start:** Read this file (`_docs/HANDOFF.md`), [`AGENTS.md`](../AGENTS.md), and [`CHANGELOG.md`](../CHANGELOG.md) before modifying tools, skills, or docs.
> 2. **Before Ending a Session or Switching Platforms:** Update sections **1 (Current State)**, **4 (Completed Work Log)**, and **5 (Next Actionable Steps)** so the next agent resumes with zero context loss.

---

## 1. Current Repository & Deployment State

### 1.1 Git, Versioning & Tool Counts
- **Repository:** `C:\Git\sas-mcp-server` (`origin`: `https://github.com/martinoschuetz/sas-mcp-server.git`, branch `main`; `david` / `upstream-local`: `C:\Git\David\sas-mcp-server`, merged through tag **`v1.22.0`** / commit `f7889fd`).
- **Package Version (`pyproject.toml`):** **`1.22.0`** (`sasram.azurecr.io/sas-mcp-server-msz:v1.22.0`, `251` tools: `115` read-only + `136` write).
- **Registered Tool Surface (`src/sas_mcp_server/tools/` & `_access.py`):**
  - **Total Registered Tools:** **`251`** across **`17` selectable tiers (`0`–`16`)**
    - **Tiers `0`–`11` (Upstream `sassoftware/sas-mcp-server` Core `v1.22.0`):** **`137` tools** + **`9` Core Prompt Templates** (`12` total with solution prompts) + **`12` MCP Apps interactive HTML views** (`query_data`, `get_castable_data`, `get_compute_table_data`, `execute_sas_code`, `get_job_log`, `submit_batch_job`, `get_glossary_term_type`, `get_glossary_term`, `list_glossary_terms`, `import_glossary_terms`, `get_mas_module_step_signature`, `score_data`).
    - **Tiers `12`–`16` (Solution Extensions):** **`114` tools** (`Tier 12`: IoT, FQA & Visual Forecasting; `Tier 13`: GenAI; `Tier 14`: SAS ESP; `Tier 15`: 14 Custom Analysis Framework tools; `Tier 16`: 3 Dynamic Knowledge Engine tools + `skill://{domain}` MCP resources).
  - **Fail-Closed Access Partition (`MCP_READ_ONLY`):** **`115` `READ_ONLY_TOOLS`** and **`136` `WRITE_TOOLS`** (enforced by `tests/test_read_only.py`).
- **Upstream `v1.21.0` & `v1.22.0` Capabilities Merged (`2026-11-25`):**
  - **Per-Endpoint Stdio Credentials (`v1.21.0`, `credentials_store.py`, `fs_perms.py`):** Multi-deployment logins in `~/.sas-mcp-server/credentials.json` keyed by normalized `VIYA_ENDPOINT`, short names in `~/.sas-mcp-server/endpoints.json` (`--name`, `--list`, `--logout`), atomic lock-protected updates (`credentials.json.lock`), and `close_client_cache()` lifespan cleanup preserved.
  - **Decision Scoring MCP App & Links (`v1.22.0`, `ui/views/decision-score.html`, `helpers/viya_links.py`):** Interactive scoring form & result card on `get_mas_module_step_signature` and `score_data`, optional `MCP_EMAIL_DRAFT` (`off` | `outlook` | `mail`), `open_url` on `list_decision_flows`/`get_decision_flow` and `get_mas_module_step_signature`, `publish_name`-based MAS module naming + `replace_existing` on `publish_decision_flow`, RFC 6749 HTTP Basic `client_id` fix for M365 Copilot (`MCP_OAUTH_CLIENT_SECRETS=true`), and `COMPATIBILITY.md` refreshed for LTS `2025.03` – Stable `2026.11`.
- **Container Registry (`sasram.azurecr.io/sas-mcp-server-msz`):**
  - All prior tags/manifests (`v1.20.1`–`v1.20.4`) purged locally and on `sasram.azurecr.io`; rebuilt and pushed exclusively as **`sasram.azurecr.io/sas-mcp-server-msz:v1.22.0`** (`linux/amd64`).
  - **Note for SAS RAM Tool Server (`7055470e-3a8d-4a94-906e-4316919f15d7`):** Container template `8aac8ba3-ecfa-4e0f-9a5b-3a3bdaa78e39` (`v13`) previously referenced `:v1.20.3`; update the RAM container template tag to **`v1.22.0`** before restarting the `sas-mcp-server-msz` pod on SAS RAM.

---

## 2. Installed Domain Skillsets (`knowledge/`)

Link all 7 skills into `.claude/skills`, `~/.claude/skills`, `.agents/skills`, `~/.agents/skills`, and `~/.gemini/config/plugins/sas/skills` via:
```powershell
python scripts/install_agent_skills.py
```

| Domain | Skill ID & Version | Key Assets | Recent Highlights |
| :--- | :--- | :--- | :--- |
| `knowledge/caf/` | **`sas-caf` `v2.1.0`** | `SKILL.md`, `mcp_execution_rules.md`, 7 `references/*.md`, `templates/build_package.py`, `evals/evals.json` | 13 live Viya rules (`RESOLVEONUI="true"` strictly on `STABLEPERIOD`, empty `<Condition>`, `<=32`-char CRC32 `QASAnlOut` + `remACs=true`, Rule 11 BIRD `<SeriesPlot>` & `55×–207×` visual table compression). |
| `knowledge/fqa/` | **`sas-fqa` `v0.6.0`** | `SKILL.md`, `mcp_execution_rules.md`, 18 `references/*.md`, `templates/fedsql/` | Added `standard-models-caf.md` (all 17 `STANDARD`/`ALERTS` contracts) and `object-lifecycle-and-api-traps.md` (11-col Launchers, `/copy` `EIENTERPRISE` rules, `@myFolder` ACLs, 423 `76003` details). |
| `knowledge/esp/` | **`sas-esp`** | `SKILL.md`, `mcp_execution_rules.md`, 6 `references/*.md` | Confluent Kafka `opaquestring` + `disableespmetaconsumer=true`, Python EAV flattening, `dfesp_cas_adapter` `commitblocks`, ESP Studio v4 REST XML deploy. |
| `knowledge/forecasting/` | **`sas-forecasting`** | `SKILL.md`, `mcp_execution_rules.md` | Hybrid `ATSM` + `EXTLANG` + `MP-CONNECT` forecasting, Borda `SUM_rk` vs. `SNAIVE` `FVA`, and `MinT` reconciliation. |
| `knowledge/api/` | **`sas-api`** | `SKILL.md`, `mcp_execution_rules.md` | SAS Viya REST pagination, vendor media types, `If-Match` ETags, and OAuth2/JWKS rules. |
| `knowledge/sas/` | **`sas-core`** | `SKILL.md`, `mcp_execution_rules.md`, sub-skills | SAS 9 & Viya DATA step, `PROC FedSQL` in CAS, macros, Viya single-node deployment, ML, text analytics. |
| `knowledge/standards/` | **`sas-standards`** | `SKILL.md`, `sas.md`, `python.md` | Async structured concurrency (`httpx`, `anyio`) and SAS performance standards. |

---

## 3. Connected Solution Repositories (Ecosystem Overview)

| Workstream | Local Path | Current State (2026-11-25) |
| :--- | :--- | :--- |
| **1. Core Viya MCP Server & Skills** | `C:\Git\sas-mcp-server` | **`v1.22.0`** (`251` tools = `115` read + `136` write, `12` MCP Apps views), `sasram.azurecr.io/sas-mcp-server-msz:v1.22.0`. |
| **2a. Headless SAS RAM MCP Server** | `C:\Git\Manfred\ram-mcp-server` (branch `germsz`) | `63` tools on `:8135`, Keycloak `offline_access` + 30-day keepalive, `run-evals.mjs`. |
| **2b. Production FQA Agent on RAM** | `C:\Git\Manfred\FQA` (branch `germsz`) | Champion `fqa-2h-msz` running Template **`v41`** (`3g-msz`, `fqa-agent==2.23.0`), `47` intents, `73` governed tools (`33` read + `40` write), `565` unit tests, `4.8/5.0` SME Certification. |
| **3. AIoT Custom Analysis Factory (CAF)** | `C:\Git\martinoschuetz\AIoT\custom_analysis` | **`18` live single-folder CAFs** (`0` SAS errors): **`12` `ASSET` Anomaly CAFs** + **`6` `PRODUCT` FQA CAFs**. |
| **4. SAS Optimizer for IoT** | `C:\Git\martinoschuetz\IOT\AIoT_Optimizer` (`feat/optimizer-for-iot-ui-rework`) | `/Products/SAS Optimizer For IoT` (`45/62` WPs `DONE`), `UniMeMo` Wilcoxon tournament, `1.5s`/shift `OPTLSO` solver, React 19 cockpit. |
| **5. SAS ESP Streaming Chains** | `C:\Git\martinoschuetz\projects\CandF` & `Qatar_Cool` | `CandF_UNS_BMC2.xml` (`90,635` rows) + `Qatar_Cool` (`30` assets, `31.52M` APA rows + 4 Grafana boards). |
| **6. SAS Visual Forecasting** | `C:\Git\martinoschuetz\Forecasting` | 11-stage 3-tier `ATSM` + `EXTLANG` + `MP-CONNECT` tournament, 9-metric Borda `SUM_rk`, Dual `MinT`, `unified_report.html`. |

---

## 4. Completed Work Log (`2026-11-17` – `2026-11-25`)

1. **`v1.20.2`–`v1.20.4` Tier 12/15 & Skill Expansions (`a9bb619` .. `afd48ca`):**
   - Added standalone `create_data_selection_tool`, Launcher CRUD, folder members, filter attributes & picklists (`list_data_selection_attributes_tool`, `get_filter_attribute_values_tool`), `423 Locked` (`errorCode 76003`) structured error preservation on `delete_data_selection_tool`, and expanded `sas-caf` `v2.1.0` & `sas-fqa` `v0.6.0`.
2. **Upstream `v1.21.0` + `v1.22.0` Merge, Full Test Suite & ACR `:v1.22.0` Cutover (`2026-11-25`):**
   - Merged `C:\Git\David\sas-mcp-server` `v1.22.0` (`f7889fd`, recording merge parent for clean future upstream merges), fixed `list_iot_analyses` `int | None` type annotations (`pyright` `0 errors`), verified `ruff` on all 18 merged modules (`0 errors`), passed **`1,484` unit tests (`93.23%` coverage)**, and passed live SAS Viya (`https://iot.viya-azure-gpu.unx.sas.com`) smoke tests across Compute, CAS, Decisioning (`open_url`), Data Selections/Picklists, CAF, and Knowledge tools.
   - Purged all legacy `sasram.azurecr.io/sas-mcp-server-msz` tags/manifests locally and on ACR, and built + pushed **`sasram.azurecr.io/sas-mcp-server-msz:v1.22.0`**.

---

## 5. Next Actionable Steps

1. **Point SAS RAM Container Template to `:v1.22.0`:** Update container template `8aac8ba3-ecfa-4e0f-9a5b-3a3bdaa78e39` on SAS RAM (`ram-mcp-server` / `Manfred/FQA`) to `sasram.azurecr.io/sas-mcp-server-msz:v1.22.0` (since `:v1.20.1`–`:v1.20.4` were deleted from ACR) so the next `sas-mcp-server-msz` pod restart pulls `:v1.22.0`.
2. **Bind Local Stdio Login to Endpoint (`v1.21.0`):** Optionally run `uv run sas-mcp-login --endpoint https://iot.viya-azure-gpu.unx.sas.com --name iot` to replace the untagged legacy `Default` block in `~/.sas-mcp-server/credentials.json` with an endpoint-scoped block.
3. **Monthly OpenAPI Refresh (`2026.11`):** Run `python scripts/download_specs.py --force` to pull SAS Viya Stable `2026.11` internal/solution specs into `docs/APIs/`.
