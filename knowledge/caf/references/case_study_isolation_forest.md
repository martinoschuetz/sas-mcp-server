# Case Study — 3-Step `ISOLATION_FOREST` CAF Analysis Type

End-to-end production architecture of **`ISOLATION_FOREST`** (`<DisplayName>Isolation Forest</DisplayName>`, `KeyGroup="ASSET"`), demonstrating how a multi-step CAF combines Data Selections & existing CAS tables, optional multi-window `STABLEPERIOD` pickers, distributed CAS machine learning (`PROC FOREST ... ISOLATION`), exact TreeSHAP explainability (`PROC GRADBOOST` + `PROC ASTORE` `TREESHAP 1`), Statistical Process Control alerting (`PROC SPC`), and a 3-tab Visual Analytics Output Layer.

---

## 1. Architecture Overview

| Step | Step ID | Purpose | UI Controls (`Basic` / `Advanced`) | Published `QASAnlOut` Outputs |
| :---: | :--- | :--- | :--- | :--- |
| **1** | `ISOLATION_FOREST_1` | Data Preparation & Self-Healing Cleanup | `DATASOURCE` (`DATSELECTION` \| `SASTABLE`), `SEL_CASLIB`, `SEL_SASTABLE` (`DROPDOWN`), `PERIODICITY` (`NUMERICSTEPPER`), `PERIODICITY_UNIT`, `AGGREGATION_METHOD` (`DROPDOWN`), `NOTAPPLICABLE` (`TEXTINPUT`) | `CASLIB`, `TRANSPOSE_TABLE` (`ISOLATION_TRANSPOSE_<shortId>`), `ASSET_VAR_TABLE` (`ISOLATION_ASSETS_<shortId>`), `TARGET_VAR_TABLE` (`ISOLATION_TAGS_<shortId>`), `EVENT_VAR_TABLE` (`ISOLATION_EVENTS_<shortId>`), plus column metadata |
| **2** | `ISOLATION_FOREST_2` | Isolation Forest Training, TreeSHAP & SPC | **Basic:** `SM_ASSET_VARIABLE` (`SINGLESELECT`), `INPUTVARS` (`MULTISELECT`), `TARGETVAR` (`SINGLESELECT`), `STABLE_PERIOD` (`STABLEPERIOD`, **optional** `required: false`)<br>**Advanced:** `NTREES` (`100`), `SEED` (`12345`) | `TS_TRANS_TABLE` (`ISOLATION_TS_TRANS_<shortId>`), `GIMPORTANCE_TABLE` (`ISOLATION_GIMPORTANCE_<shortId>`), `TS_SHA_T_TABLE` (`ISOLATION_TS_SHA_T_<shortId>`), plus Step 3 lookup tables (`SEL_ASSET_TABLE`, `SEL_TAG_TABLE`, `FIL_TRANSPOSE_TABLE`) and persisted ASTOREs (`ISOLATION_<KEY8>_M1_<shortId>`, `ISOLATION_<KEY8>_M2_<shortId>`) |
| **3** | `ISOLATION_FOREST_3` | Holdout / Multi-Window Scoring & SPC | `SCORE_ASSET_VARIABLE` (`DROPDOWN`), `SCORE_TARGET_VARIABLE` (`DROPDOWN`), `SCORE_PERIOD` (`STABLEPERIOD`, `required: true`) | `GIMPORTANCE_TABLE`, `TS_TRANS_SCO_TABLE` (`ISOLATION_TS_T_SCO_<shortId>`), `TS_SHA_T_SCO_TABLE` (`ISOLATION_TS_SHA_T_SCO_<shortId>`) |

---

## 2. Key Design Decisions & Lessons Applied

1. **Optional vs. Multi-Window `STABLE_PERIOD`:**
   - Unlike hypersphere boundary methods (`PROC SVDD`) that strictly require clean inlier training windows, Isolation Forest isolates sparse anomalies near the root ($s(\mathbf{x}_t, \psi) = 2^{-E[h(\mathbf{x}_t)]/c(\psi)} \in [0, 1]$) even on unlabeled full-history streams.
   - `STABLE_PERIOD` is configured with `"required": false` and `"properties": {"SKIP_VALIDATION": "true"}`. When left blank, `generate_time_filter` emits `G_TIME_FILTER = (1=1)`. When populated with 1 or more windows (e.g., 3 disjoint healthy windows in Step 2 and 2 disjoint scoring windows in Step 3), `%superq(G_STABLE_PERIOD)` builds exact disjunctive `(DATETIME ge ... and DATETIME le ...) or ...` CAS filters with zero gap leakage.
2. **Strict `RESOLVEONUI=true` Isolation:**
   - `IF_STABLE_PERIOD_LKP` and `IF_SCORE_PERIOD_LKP` (`STABLEPERIOD`) are the **only** lookups with `"properties": {"RESOLVEONUI": "true"}`.
   - `IF_SASTABLE_LKP` (`DROPDOWN`), `IF_SM_ASSET_LKP` (`SINGLESELECT`), `IF_INPUTVARS_LKP` (`MULTISELECT`), `IF_TARGETVAR_LKP` (`SINGLESELECT`), `IF_SCORE_ASSET_LKP` (`DROPDOWN`), and `IF_SCORE_TARGET_LKP` (`DROPDOWN`) all set `"properties": {}` and cascade via empty-condition SpEL `<Interactions>`, guaranteeing `100%` retention of saved UI parameters on step reopen.
3. **Pre-Training Input Screen (`VARSCREEN_TABLE`) & Frozen Graded Severity (`THRESH_IF` / `DMAX_IF`):**
   - Ported from `SVDD_ASSET` (`Custom/SVDD/`): Step 2 screens selected inputs before training and auto-excludes elapsed-time counters (`|corr(x, DATETIME)| >= 0.90` — catching `RH_HRS` at `0.9566` on `Chiller 18B`) and constant baseline tags (`STABLE_RANGE <= 0`), publishing `VARSCREEN_TABLE` and freezing surviving inputs for Step 3. (Trees are scale-invariant, so `STDSTAT` is omitted.)
   - Replaces collapsed autocorrelated `PROC SPC` I-MR limits with frozen baseline `THRESH_IF` ($P_{99}$ of training `_Anomaly_`), `DMAX_IF`, normalised `MARGIN_IF` (`0.25` Watch / `0.60` Warning), 4-level `SEVERITY_IF` (`0 Normal..3 Alarm`), and `WARN_RUNLEN = 3` persistence confirmation (`PROC SPC` runs only for Western Electric / Nelson `_TESTS_`).
4. **Global & Local Explainability (`PROC GRADBOOST` + `TREESHAP 1` + Rule 11 Alignment):**
   - Because `PROC FOREST ... ISOLATION` produces `_Anomaly_` without per-timestamp feature attributions, Step 2 fits a `PROC GRADBOOST` surrogate (`M2` ASTORE, $R^2 > 0.98$–$0.99$) and scores `PROC ASTORE` with `setoption TREESHAP 1;` (`P__Anomaly_`, `S__Anomaly_<Tag>`). *(Tip: omit `crossvalidation kfold=5;` unless CV metrics are published to save ~22s per asset.)*
   - Stripping the 11-character `S__Anomaly_` prefix (`vname = substr(_name_, 12)`) aligns `vname` with sensor names. Both Step 2 & Step 3 VA templates are hardened to Rule 11 (`<SASReportState><View/></SASReportState>`, continuous `<SeriesPlot>`, `maxRows="250000" maxRowsBehavior="truncate"`, explicit filter interactions, and Local Explainer `dm372`/`ve364` aligned on `(vname -> _NAME_, PAM_ASSET_ID)` without `DATETIME`).
5. **32-Character-Safe Naming & Self-Healing Step 1 Pre-Cleanup:**
   - Asset IDs like `IDCP_CH18B` (`10` chars) are mapped via CRC32 to 8-character keys (`IDCP_CHB` / `<CLEAN4><CRC4>`) so `ISOLATION_<KEY8>_M1_<shortId>` never exceeds `30` characters (`<= 32`).
   - Step 1 opens an isolated CAS session to drop stale `ISOLATION_*_<shortId>` tables (`remACs=true`) and delete `.sashdat` files before `%anl_driver` runs, preventing Step 1 re-run crashes in `accessControl.updSomeAcsTable`.
6. **Companion Reference Packages:** `SVDD_ASSET` (*Support Vector Data Description*, adds frozen `STDSTAT`), `MTS_SIMPLE` (*Mahalanobis-Taguchi Simple*, condition-capped ridge precision $\kappa \le 10^4$, configurable `THRESHOLD_PCTL` & `WARN_RUNLEN`, exact additive contributions without GB), and 5-step `MTS` (`revisionNo=2`).
