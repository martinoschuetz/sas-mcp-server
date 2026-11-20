import asyncio
import json
import os
import shutil
from PIL import Image, ImageChops
from playwright.async_api import async_playwright

SCRATCH_ASSETS = os.environ.get("PPTX_ASSETS_DIR", os.path.join(os.path.dirname(__file__), "pptx_assets"))
OLD_ASSETS = os.environ.get("PPTX_SEED_ASSETS_DIR", SCRATCH_ASSETS)
os.makedirs(SCRATCH_ASSETS, exist_ok=True)

# Backup existing presentation before touching anything
BACKUP_PPTX = os.environ.get("PPTX_TEMPLATE_BACKUP", os.path.join(SCRATCH_ASSETS, "SAS_Viya_MCP_Server_backup.pptx"))
if not os.path.exists(BACKUP_PPTX):
    shutil.copy2(r"C:\Git\sas-mcp-server\SAS_Viya_MCP_Server.pptx", BACKUP_PPTX)
    print("Backed up original PPTX to:", BACKUP_PPTX)

for asset_nm in ["fqa_video_poster.png", "nestle_slide75_composite.png"]:
    src_p = os.path.join(OLD_ASSETS, asset_nm)
    dst_p = os.path.join(SCRATCH_ASSETS, asset_nm)
    if os.path.exists(src_p) and not os.path.exists(dst_p):
        shutil.copy2(src_p, dst_p)
        print("Copied asset:", asset_nm)

MERMAID_DIAGRAMS = {
    "m02_mcp_extension": """flowchart LR
    classDef oss fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ext fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef kb fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef sol fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph S1["1. Open-Source Baseline"]
      A1("Official SAS Viya MCP Repo<br/>sassoftware/sas-mcp-server"):::oss
      A2("137 Core Tools (Tiers 0–11)<br/>+ 10 MCP Apps HTML Views"):::oss
    end

    subgraph S2["2. Monthly API Overhaul"]
      B1("Automated Spec Harvester<br/>scripts/download_specs.py"):::ext
      B2("333 OpenAPI YAML Specs<br/>Public + Internal in docs/APIs"):::ext
    end

    subgraph S3["3. Live-Verified Playbooks"]
      C1("7 Domain Skillsets in knowledge/<br/>Deep CAF v2.1 & FQA v0.6 Rules"):::kb
      C2("On-Demand Tier 16 & skill://<br/>+ Local IDE & SAS RAM Sync"):::kb
    end

    subgraph S4["4. Dual-Server Solution Engine"]
      D1("sas-mcp-server (251 Tools)<br/>+ ram-mcp-server (63 RAM Tools)"):::sol
      D2("FQA • CAF (18 Suites) • Optimizer<br/>SAS ESP • Visual Forecasting"):::sol
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m03_download_specs": """flowchart LR
    classDef step fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef store fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef agent fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph P1["1. Monthly SAS Viya Release"]
      A1("developer.sas.com/rest-apis<br/>Public & Internal API Portal"):::step
      A2("Authenticated Browser Session<br/>SSO State + WAF Jitter"):::step
    end

    subgraph P2["2. Playwright Extraction Engine"]
      B1("scripts/download_specs.py<br/>Next.js Payload Scraper"):::step
      B2("Extracts OpenAPI 3.0 YAML<br/>+ Endpoint Documentation"):::step
    end

    subgraph P3["3. Versioned Local Spec Vault"]
      C1("docs/APIs Repository<br/>333 YAML Specs / 14 Categories"):::store
      C2("AIoT • FQA • CAF • Launchers<br/>Forecasting • ESP • Governance"):::store
    end

    subgraph P4["4. Agentic Tool Synthesis"]
      D1("Claude & Gemini Coding Agents<br/>Inspect Exact Schemas & ETags"):::agent
      D2("Synthesize 251 Typed MCP Tools<br/>+ Access Gates & CI Tests"):::agent
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m04_skill_flywheel": """flowchart LR
    classDef src fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef kb fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef mcp fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef loop fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph K1["1. Multi-Source Knowledge"]
      A1("Gemini Notebooks + Literature<br/>Warranty • Anomaly • ESP • Forecast"):::src
      A2("Playwright Docs • ETL Scripts<br/>AIoT app.js & BIRD XML Forensics"):::src
    end

    subgraph K2["2. 7 Domain Skillsets (knowledge/)"]
      B1("sas-caf v2.1 (13 Live Rules + 7 Refs)<br/>sas-fqa v0.6 (17 Models + API Traps)"):::kb
      B2("sas-esp • sas-forecasting • sas-api<br/>sas-core • sas-standards + Templates"):::kb
    end

    subgraph K3["3. Dynamic Runtime Extraction"]
      C1("list_knowledge_domains()<br/>read_knowledge_topic()"):::mcp
      C2("search_knowledge(pattern)<br/>skill:// URI & install_agent_skills.py"):::mcp
    end

    subgraph K4["4. Continuous Co-Evolution"]
      D1("Daily Project Work Across 6 Repos<br/>Uncovers Runtime & UI Traps"):::loop
      D2("Agent Adds Bundled Tools,<br/>Updates Skills & Verifies Live"):::loop
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
    D2 -.->|"Instant Feedback Loop"| B2
""",
    "m05_tiers_arch": """flowchart LR
    classDef agent fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef core fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef sol fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph G1["1. AI Clients & Orchestrators"]
      A1("Claude • Gemini • Antigravity<br/>VS Code • M365 Copilot • ChatGPT"):::agent
      A2("SAS Retrieval Agent Manager<br/>sas-mcp-server-msz:v1.20.2 Pod"):::agent
    end

    subgraph G2["2. FastMCP Governance (:8134)"]
      B1("251 Tools • 115 Fail-Closed Read<br/>MCP Tool Annotations & 10 UI Views"):::core
      B2("MCP_TIERS & MCP_READ_ONLY<br/>OAuth2 PKCE + Raw Bearer JWKS"):::core
    end

    subgraph G3["3. Tiers 0–11: Viya Core (137)"]
      C1("Tiers 0–3: Compute + ODS HTML5,<br/>Catalog NLP, CAS/SQL & VA BIRD"):::core
      C2("Tiers 4–11: Jobs, AutoML, MAS,<br/>Decisioning, Glossary & Model Mgr"):::core
    end

    subgraph G4["4. Tiers 12–16: Solutions (114)"]
      D1("Tier 12: FQA, Picklists & Forecast<br/>Tier 13: GenAI • Tier 14: ESP"):::sol
      D2("Tier 15: 14 CAF Authoring Tools<br/>Tier 16: Dynamic Skill Engine"):::sol
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m06_governance": """flowchart LR
    classDef gate fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef sas fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef heal fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef out fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph R1["1. Mandatory Skill & Schema Gate"]
      A1("Load Domain Playbook First<br/>read_knowledge_topic('SKILL')"):::gate
      A2("Schema & Domain Guard<br/>Never Guess Columns or Hashes"):::gate
    end

    subgraph R2["2. Single-Call Preflight Gate"]
      B1("run_fqa_preflight_checks_tool<br/>Unit Volume & Distinct Levels"):::gate
      B2("Cardinality ≤ 500 • Comments ≥ 50<br/>Multi-Code Unit Share ≥ 20%"):::gate
    end

    subgraph R3["3. Zero Mental Math & Healing"]
      C1("100% SAS/CAS Unit-Level Math<br/>DISTINCT PRODUCT_ID • Weibull • MinT"):::sas
      C2("3-Strikes Log Self-Healing<br/>+ Explicit Approve / Undo Gate"):::heal
    end

    subgraph R4["4. Auditable Enterprise Output"]
      D1("Automatic PII Redaction +<br/>Untrusted Text Tag Isolation"):::out
      D2("Persistent Viya UI Artifacts<br/>Projects, Selections & CAF Views"):::out
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m07_fqa_doc_etl": """flowchart LR
    classDef nb fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef doc fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef etl fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef out fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph F1["1. Domain Literature Context"]
      A1("Warranty Gemini Notebook<br/>Reliability & Common Cause Rules"):::nb
      A2("Reliability Metrics Guide<br/>Weibull β CI & B-Life T01–T25"):::nb
    end

    subgraph F2["2. Playwright Doc Generation"]
      B1("Automated Help-Portal Extraction<br/>sas-analytics-for-iot-md"):::doc
      B2("180 Markdown Files + 341 Images<br/>Across 14 Self-Contained Doc Sets"):::doc
    end

    subgraph F3["3. Reverse-Engineered ETL & APIs"]
      C1("Customer DEW + %afi_dataload<br/>15 Staging Tables • 480 Variables"):::etl
      C2("17 CAF Model Specs + REST Traps<br/>Launchers • Folders • 423 Guards"):::etl
    end

    subgraph F4["4. Unified sas-fqa v0.6 Skillset"]
      D1("knowledge/fqa/ Playbooks<br/>18 Topic Guides + FedSQL Templates"):::out
      D2("Powers Antigravity CLI, Claude<br/>& Champion FQA_msz on SAS RAM"):::out
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m08_fqa_funnel": """flowchart LR
    classDef p0 fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef p1 fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef p2 fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef p3 fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph W0["Phase 0: Triage & Common Cause"]
      A1("triage_emerging_issue_runs_tool<br/>Single-Call CAS Ranking + Top-10"):::p0
      A2("3rd Time Dim: Sales Lag C_ijk<br/>+ 4-Quadrant Common Cause Screen"):::p0
    end

    subgraph W1["Phase 1 & 4: Descriptive + Weibull"]
      B1("fqa_template_descriptive_triage<br/>Pareto • Geo • Grouped Exposure"):::p1
      B2("Early Normalization: Weibull β<br/>95% CI Overlap & T01–T25 B-Life"):::p1
    end

    subgraph W2["Phase 2: Segmentation & Dilution"]
      C1("ANOM Drivers + Decision Tree<br/>evaluate_subpopulation_lift"):::p2
      C2("4-Yr Exposure Dilution Factor<br/>+ ≥25% Unit Coverage Gate"):::p2
    end

    subgraph W3["Phase 3: Widening & Synthesis"]
      D1("Auto-Widen Cohort Before<br/>Text Mining & Failure Relations"):::p3
      D2("synthesize_root_cause_selection<br/>1 Pruned DS + UI Detail & Pareto"):::p3
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m10a_ram_mcp_server": """flowchart LR
    classDef cli fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef srv fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ops fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ram fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph M1["1. Cross-Agent Continuity"]
      A1("Claude Code ↔ Google Antigravity<br/>Python SDK & Node Eval Runners"):::cli
      A2("AGENTS.md • CLAUDE.md • GEMINI.md<br/>+ Live _docs/HANDOFF.md Ledger"):::cli
    end

    subgraph M2["2. ram-mcp-server (63 Tools)"]
      B1("Stdio & Streamable HTTP (:8135)<br/>Beside sas-mcp-server (:8134)"):::srv
      B2("Keycloak Device-Code + PKCE<br/>30-Day Keepalive & 20 KB Cap"):::srv
    end

    subgraph M3["3. Headless RAM DevOps"]
      C1("Push 1-File Wheel Templates<br/>Sync 71-Tool Allow-Lists"):::ops
      C2("Race-Safe Dev/Prod Pod Restarts<br/>Compact Traces & Filtered Logs"):::ops
    end

    subgraph M4["4. Staged Gates & Promotion"]
      D1("run-evals.mjs & 5-Persona SME<br/>Automated Regression Grading"):::ram
      D2("promote_staging_to_champion<br/>Zero-Click Production Rollout"):::ram
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m10b_fqa_ram_agent": """flowchart LR
    classDef ent fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef fsm fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef gov fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef cert fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph A_1["1. Guided Co-Pilot Entry (3f-msz)"]
      N1("Exact Commands (Approve / Undo)<br/>Zero-LLM Fast Path"):::ent
      N2("DRIVE@v5 + INTERPRET@v14 +<br/>ROUTE@v19 Across 47 Intents"):::ent
    end

    subgraph A_2["2. Deterministic FSM + Decisions"]
      F1("AlertFlow & DSFlow State Machines<br/>Dual Narrow/Wide Scoping (2m)"):::fsm
      F2("Schema-Validated D1–D11 Calls<br/>+ 100% Deterministic Fallback"):::fsm
    end

    subgraph A_3["3. Governed 71-Tool Execution"]
      G1("sas-mcp-server-msz:v1.20.2<br/>31 Read + 40 Gated Write Tools"):::gov
      G2("Full DS / Launcher / Analysis /<br/>Project / Folder CRUD + Undo"):::gov
    end

    subgraph A_4["4. Verified Champion Quality"]
      Q1("558 Unit Tests • 76 Smoke Cases<br/>DEC-EVAL 46/46 (100% Match)"):::cert
      Q2("5-Persona SME Score: 4.8 / 5.0<br/>Drastic Token Savings on RAM"):::cert
    end

    N1 ==> F1
    F1 ==> G1
    G1 ==> Q1
    N2 ==> F2
    F2 ==> G2
    G2 ==> Q2
""",
    "m11_bioreactor_arch": """flowchart LR
    classDef uns fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef kaf fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef esp fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef cas fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph B1["1. C&F UNS Bioreactor Edge"]
      A1("bio01 • bio02 (2kL) • bio03 (5kL)<br/>14 Tags • 10 Fed-Batch Phases"):::uns
      A2("Compressed Clock: 14d ≈ 8–10m<br/>Point, DO Drop & Glucose Spikes"):::uns
    end

    subgraph B2["2. Confluent Cloud Kafka"]
      B1_N("Topic: uns.dev.uns.clv.gbl.sas<br/>CloudEvents + Telemetry JSON"):::kaf
      B2_N("7-Day Retention (~56k msgs/wk)<br/>Missing specversion Handled"):::kaf
    end

    subgraph B3["3. SAS ESP (CandF_UNS_BMC2)"]
      C1("w_source (opaquestring, blk=1000)<br/>disableespmetaconsumer=true"):::esp
      C2("w_flatten (18 Typed EAV Cols) →<br/>w_to_cas (commitblocks=10)"):::esp
    end

    subgraph B4["4. CAS ABT & SAS VA (/Public/BMC)"]
      D1("PUBLIC.BMC_RAW (90.6k Rows)<br/>Event-Level Hysteresis & 15–30s Grid"):::cas
      D2("Viability RCA • Harvest RUL GAM<br/>• bio03 Foam-Out Prevention"):::cas
    end

    A1 ==> B1_N
    B1_N ==> C1
    C1 ==> D1
    A2 ==> B2_N
    B2_N ==> C2
    C2 ==> D2
""",
    "m12_esp_pipeline": """flowchart LR
    classDef nb fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef fix fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef cas fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef qc fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph E1["1. ESP Skillset (knowledge/esp)"]
      A1("ESP Gemini Notebook + 2026.08 Docs<br/>+ sassoftware/esp-studio-examples"):::nb
      A2("Tier 14 esp_deploy_project<br/>ESP Studio v4 REST XML Wrapper"):::nb
    end

    subgraph E2["2. Confluent Kafka Replay Fixes"]
      B1("opaquestring Raw JSON Mode +<br/>disableespmetaconsumer=true"):::fix
      B2("Low-Watermark Offset Reset<br/>Replays Complete 7-Day Stream"):::fix
    end

    subgraph E3["3. Hardened CAS Stream Writer"]
      C1("dfesp_cas_adapter + BIGINT Key<br/>µs Stamp → CAS Datetime"):::cas
      C2("blocksize=1000 & commitblocks=10<br/>Eliminates 17.5k EOFException"):::cas
    end

    subgraph E4["4. District Cooling (Qatar Cool)"]
      D1("30 Chillers & Cooling Towers<br/>31.5M Rows in Parallel APA+FQA"):::qc
      D2("Real-Time dcs_chiller SVDD ASTORE<br/>+ dcs_ct KPIs → 4 Grafana Boards"):::qc
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m14a_caf_factory": """flowchart LR
    classDef src fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef bld fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef mcp fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef run fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph C1["1. Single-Folder Source Standard"]
      A1("spec.json (UI & SpEL ctx) +<br/>steps/*.sas (Pure In-CAS Code)"):::src
      A2("output/*_vaoutput.template +<br/>14 Standard & 3 Alert References"):::src
    end

    subgraph C2["2. Zero-Drift Compiler & Rules"]
      B1("build_package.py --check<br/>Generates input_layer.xml & .zip"):::bld
      B2("sas-caf v2.1: RESOLVEONUI Guard,<br/>≤32-Char CRC32 & Rule 11 BIRD"):::bld
    end

    subgraph C3["3. Tier 15 MCP Deployment"]
      C1_N("validate_analysis_type_spec &<br/>templatize_va_report"):::mcp
      C2_N("create / update_analysis_type<br/>(If-Match ETag & revision_no)"):::mcp
    end

    subgraph C4["4. Live Viya Verification"]
      D1("Plan A+B+C: 55×–207× Smaller<br/>VA Tables & SeriesPlot Speed"):::run
      D2("Mandatory Multi-Step Smoke Run:<br/>0 SAS Errors & Hydrated VA PDF"):::run
    end

    A1 ==> B1
    B1 ==> C1_N
    C1_N ==> D1
    A2 ==> B2
    B2 ==> C2_N
    C2_N ==> D2
""",
    "m14b_caf_anomaly_suite": """flowchart LR
    classDef det fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ens fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef tax fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ssdo fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph N1["1. 11 Orthogonal ASSET CAFs"]
      A1("SVDD • Isolation Forest • MTS/Simple<br/>Univariate MAX_AFTER • Spectrogram"):::det
      A2("Robust PCA (CoMuT) • KT Drift/R²<br/>Autoencoder • GMM • Sensor GDN"):::det
    end

    subgraph N2["2. Flagship ANOMALY_ENSEMBLE"]
      B1("Fault-Tolerant 8-Engine Committee<br/>0% Multivariate Crash Guardrail"):::ens
      B2("POT-GPD Tail Calibration +<br/>Spearman & Wilcoxon Weighting"):::ens
    end

    subgraph N3["3. Physics & Honest Eval"]
      C1("MAX_AFTER (n=1) vs. CoMuT (n≥2)<br/>Synergy & F1–F6 Fault Taxonomy"):::tax
      C2("TreeSHAP + White-Box Rules +<br/>Keogh–Wu Triviality Audit (No PA-F1)"):::tax
    end

    subgraph N4["4. Step 4 Active SSDO Feedback"]
      D1("Operator Verdicts: +1 Fault |<br/>0 Sensor Noise | -1 Novelty"):::ssdo
      D2("Chiller 18B: -53.6% False Alarms<br/>+9.25% Precision & ASTORE Export"):::ssdo
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m15_caf_fqa_suite": """flowchart LR
    classDef gap fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef p1 fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef p2 fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ui fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph Q1["1. Standard FQA Blind Spots"]
      A1("Unstratified 1D ANOM & Greedy<br/>Trees Fragment Multi-Factor RCA"):::gap
      A2("4-Year Dilution, Manual BP-7<br/>Weibull Clicks & Lot-Rot Hidden"):::gap
    end

    subgraph Q2["2. Drivers & Scope (order 30–31)"]
      B1("FQA_RF_DRIVERS: 4-Learner CAS<br/>AUC=0.989 • CMH • BUILDOPTIONS"):::p1
      B2("FQA_SUBGROUP_RULES: EB Beam<br/>2.32x Dilution • 6.46x Recall Eff."):::p1
    end

    subgraph Q3["3. Weibull & Survival (32–33)"]
      C1("FQA_COMMON_CAUSE: 200-Code<br/>Weibull MLE 4-Quadrant Matrix"):::p2
      C2("FQA_SURVIVAL_COX: C=0.905<br/>Lot-Rot HR=1.82x & Reserve $"):::p2
    end

    subgraph Q4["4. Phase 3 & Native FQA UI"]
      D1("FQA_LAUNCH_CAPA: CUSUM Step<br/>& PRECURSOR_LINK (4.1x Lift)"):::ui
      D2("All 6 PRODUCT CAFs Live in Viya<br/>Verified in MCP Test (0 Errors)"):::ui
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m16_aiot_optimizer": """flowchart LR
    classDef gov fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef mod fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef opt fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef ui fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph O1["1. Multi-User Registry & DQ"]
      A1("AIOT_META Project Locks & Shares<br/>Demo • Brick (WB) • Paving (VDS)"):::gov
      A2("SASDataGovernance 7-Pillar DQ<br/>+ Daily Gas & EU ETS CO₂ Rates"):::gov
    end

    subgraph O2["2. Cliques & UniMeMo Surrogates"]
      B1("Kreher–Stinson network.clique<br/>(271 Cliques) + 4-Selector Vote"):::mod
      B2("4-Learner Tournament (GB/RF/GLM/SVM)<br/>Wilcoxon Rank + opt_eligible Gate"):::mod
    end

    subgraph O3["3. 163x Faster Setpoint Solver"]
      C1("In-Memory PROC FCMP ASTORE +<br/>PROC OPTMODEL / OPTLSO (~1.5s)"):::opt
      C2("MIES Integer PID Step Lattice Δx<br/>+ Coupled Zone Thermal ΔT Bounds"):::opt
    end

    subgraph O4["4. 5-Report VA + React 19 Cockpit"]
      D1("01 Overview • 02 Project & Layout<br/>03 Status/SPC • 04 Ranked Profiler"):::ui
      D2("05 Full-Width Optimizer & Savings<br/>94/94 E2E + 8 Live SAS Gates PASS"):::ui
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m17_forecasting": """flowchart LR
    classDef sas fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef py fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef rec fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef out fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph V1["1. Auto-Pilot Profiler & Prep"]
      A1("4-Param CLI + Chunked SWAT/ZIP<br/>pricedata • m5_subset • m5_full"):::sas
      A2("01_data_profiler + ADI/CV² +<br/>FASTCLUS 3-Cluster Routing"):::sas
    end

    subgraph V2["2. 3-Tier Hybrid Tournament"]
      B1("Native CAS ATSM + CAS EXTLANG<br/>(ESM/ARIMAX/UCM/IDM/Prophet/SF)"):::sas
      B2("PROC PYTHON & MP-CONNECT Grid<br/>(LightGBM • TFT • Chronos • Bass)"):::py
    end

    subgraph V3["3. Borda Rank & Dual MinT"]
      C1("9-Metric Borda Sum (SUM_rk)<br/>vs. Seasonal-Naive FVA Floor"):::rec
      C2("PROC IML Schäfer–Strimmer MinT<br/>Hierarchy + Cross-Temporal (M/Q/S)"):::rec
    end

    subgraph V4["4. Stability & Unified Reports"]
      D1("70_stability.sas: Revision<br/>Nervousness & Runtime Telemetry"):::out
      D2("8-View SAS VA & Plotly HTML5<br/>Multi-Dataset Unified Dashboard"):::out
    end

    A1 ==> B1
    B1 ==> C1
    C1 ==> D1
    A2 ==> B2
    B2 ==> C2
    C2 ==> D2
""",
    "m21_unified_loop": """flowchart LR
    classDef s1 fill:#fff3e0,stroke:#E66C37,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef s2 fill:#e3f2fd,stroke:#0766D1,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef s3 fill:#eef2ff,stroke:#072B55,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef s4 fill:#fce4ec,stroke:#86134F,stroke-width:2.5px,color:#012036,font-weight:bold;
    classDef s5 fill:#e8f8f2,stroke:#15B57B,stroke-width:2.5px,color:#012036,font-weight:bold;

    subgraph L1["1. SAS ESP"]
      A1("Kafka UNS Telemetry<br/>Python Flatten → CAS"):::s1
      A2("Sub-Second Edge &<br/>Grafana Alerts"):::s1
    end

    subgraph L2["2. AIoT CAF (ASSET)"]
      B1("12 Anomaly CAFs +<br/>8-Engine Ensemble"):::s2
      B2("CoMuT Graph Links &<br/>3-Way SSDO Memory"):::s2
    end

    subgraph L3["3. Optimizer for IoT"]
      C1("UniMeMo Surrogates<br/>+ Clique Filtering"):::s3
      C2("1.5s OPTLSO Setpoints<br/>Energy & CO₂ Savings"):::s3
    end

    subgraph L4["4. FQA + RAM + CAF"]
      D1("FQA_msz v40 on RAM<br/>+ 6 PRODUCT CAFs"):::s4
      D2("Cohort Lift, Weibull<br/>& Cox Lot-Rot RCA"):::s4
    end

    subgraph L5["5. Visual Forecasting"]
      E1("3-Tier ATSM + OSS<br/>9-Metric Borda Rank"):::s5
      E2("Cross-Level & Temporal<br/>MinT Spares Plan"):::s5
    end

    A1 ==> B1 ==> C1 ==> D1 ==> E1
    A2 ==> B2 ==> C2 ==> D2 ==> E2
""",
}

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    margin: 0;
    padding: 20px;
    background: #FFFFFF;
    font-family: 'Anova', 'Segoe UI', Arial, sans-serif;
  }
  #diagram {
    background: #FFFFFF;
  }
  .cluster rect {
    rx: 10px !important;
    ry: 10px !important;
    fill: #F8FAFC !important;
    stroke: #64748B !important;
    stroke-width: 2px !important;
  }
  .cluster-label span, .cluster-label text, .cluster-label div {
    font-weight: 800 !important;
    color: #072B55 !important;
    fill: #072B55 !important;
  }
</style>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
</head>
<body>
<div id="diagram"></div>
<script>
  mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    flowchart: { htmlLabels: true, curve: 'basis', nodeSpacing: 42, rankSpacing: 34, padding: 18 },
    themeVariables: {
      fontFamily: 'Anova, Segoe UI, Arial, sans-serif',
      fontSize: '18px',
      lineColor: '#0766D1'
    }
  });
  window.__renderDiagram = async (code) => {
    const { svg } = await mermaid.render('m_svg', code);
    document.getElementById('diagram').innerHTML = svg;
  };
</script>
</body>
</html>
"""


def autocrop_white(img_path: str, pad: int = 10) -> tuple[int, int]:
    with Image.open(img_path) as im:
        rgb = im.convert("RGB")
        bg = Image.new("RGB", rgb.size, (255, 255, 255))
        diff = ImageChops.difference(rgb, bg).convert("L").point(lambda v: 255 if v > 6 else 0)
        bbox = diff.getbbox()
        if bbox:
            x0 = max(0, bbox[0] - pad)
            y0 = max(0, bbox[1] - pad)
            x1 = min(rgb.width, bbox[2] + pad)
            y1 = min(rgb.height, bbox[3] + pad)
            cropped = rgb.crop((x0, y0, x1, y1))
        else:
            cropped = rgb
        cropped.save(img_path, quality=100)
        return cropped.size


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel="msedge", headless=True)
        page = await browser.new_page(viewport={"width": 3400, "height": 1800}, device_scale_factor=2)
        await page.set_content(HTML_TEMPLATE, wait_until="networkidle")
        for name, code in MERMAID_DIAGRAMS.items():
            await page.evaluate(f"window.__renderDiagram({json.dumps(code)})")
            await page.wait_for_selector("#diagram svg")
            await page.wait_for_timeout(120)
            txt_content = await page.inner_text("#diagram")
            if "Syntax error" in txt_content:
                raise RuntimeError(f"Mermaid syntax error in {name}: {txt_content}")
            await page.evaluate("""() => {
                const svg = document.querySelector('#diagram svg');
                if (svg && svg.viewBox && svg.viewBox.baseVal) {
                    const vb = svg.viewBox.baseVal;
                    svg.style.maxWidth = 'none';
                    svg.setAttribute('width', Math.ceil(vb.width * 1.8) + 'px');
                    svg.setAttribute('height', Math.ceil(vb.height * 1.8) + 'px');
                }
            }""")
            await page.wait_for_timeout(80)
            el = await page.query_selector("#diagram svg")
            out_path = os.path.join(SCRATCH_ASSETS, f"{name}.png")
            await el.screenshot(path=out_path)
            w, h = autocrop_white(out_path, pad=12)
            print(f"Rendered & cropped {name}.png -> {w}x{h} px (aspect {w/h:.2f}:1)")
        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
