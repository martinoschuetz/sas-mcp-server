# Anomaly Detection CAF Design, Guardrails & Performance Patterns

Battle-tested methodology, algorithmic guardrails, and performance rules verified across the production anomaly CAFs (`SVDD_ASSET`, `ISOLATION_FOREST`, `MTS_SIMPLE`, and 5-step `MTS`) on SAS Viya 2026 (`iot.viya-azure-gpu.unx.sas.com`, 8-worker CAS grid, `Chiller 18B` 5-min telemetry). Distilled from `Custom/*/README.md`, `Docu/Anomaly.md`, and `ANOMALY_SUITE_PLAN.md`.

---

## 1. Unified 3-Step Anomaly CAF Blueprint

All modern anomaly detection CAFs (`SVDD_ASSET`, `ISOLATION_FOREST`, `MTS_SIMPLE`) share a consistent 3-step UX and output schema:

| Step | Purpose | Key Controls | Core `QASAnlOut` Artifacts (`<= 32` chars, `_&g_instance_nm` last) |
| :---: | :--- | :--- | :--- |
| **1** | Data Prep & Cleanup | `DATASOURCE` (`DATSELECTION` \| `SASTABLE`), `SEL_CASLIB`, `SEL_SASTABLE`, `PERIODICITY`, `PERIODICITY_UNIT`, `AGGREGATION_METHOD` | Pre-cleanup (`remACs=true`), `<PREFIX>_TRANSPOSE_<id>`, `_ASSETS_`, `_TAGS_`, `_EVENTS_` |
| **2** | Input Screen, Train, Severity & Explain | `SM_ASSET_VARIABLE` (`SINGLESELECT`), `INPUTVARS` (`MULTISELECT`), `TARGETVAR` (`SINGLESELECT`), `STABLE_PERIOD` (`STABLEPERIOD`), model/sensitivity params | `_VARSCREEN_<id>`, `_STDSTAT_<id>` / `_INVCORR_<id>`, `_<KEY8>_M1/M2_<id>`, `_GIMPORTANCE_<id>`, `_TS_TRANS_<id>`, `_TS_SHA_T_<id>` |
| **3** | Holdout Scoring & Frozen Alerting | `SCORE_ASSET_VARIABLE` (`DROPDOWN`), `SCORE_TARGET_VARIABLE` (`DROPDOWN`), `SCORE_PERIOD` (`STABLEPERIOD`) | `_TS_T_SCO_<id>`, `_TS_SHA_T_SCO_<id>` scored strictly against **Step 2 frozen** inputs, scale, & threshold |

---

## 2. Five Mandatory Algorithmic Guardrails (`[VERIFIED]`)

### 1. Pre-Training Input-Variable Screen (`VARSCREEN`)
Runtime odometers/elapsed-time counters or constant training tags destroy multivariate & tree anomaly models while looking "perfect" in training diagnostics (e.g., on `Chiller 18B`, `RH_HRS` had `|corr(x, DATETIME)| = 0.957` and pinned out-of-window scores at ceiling; `TSP_DEGC` was constant at `4.0` in the stable window):
- Compute `TIME_CORR = |corr(x, DATETIME)|` over full history and `STABLE_RANGE = max - min` inside `STABLE_PERIOD` (note: do this in CAS via `simple.correlation` + `simple.summary` — `~0.12s`).
- Auto-exclude (`DROP`) inputs where `TIME_CORR >= 0.90` or `STABLE_RANGE <= 0` (keeping at least `SCREEN_MIN_KEEP = 2` inputs).
- Report low `STABLE_COVER` (`< 0.25`) as `WARN` only — genuine sensors often have wide extreme transients outside the healthy baseline.
- Persist `<PREFIX>_VARSCREEN_<id>` and reload the surviving variable list in Step 3 (`where DECISION not like 'DROP%'`) so Step 3 never scores with a drifted input set.

### 2. Frozen Standardisation (`STDSTAT`) + Raw Engineering Units for Explainers
- `PROC SVDD ... / bw=mean2` and `MTS` precision matrices are scale-sensitive (`CHWFR_GPM` SD `4,033` vs. `TSP_DEGC` SD `0.05` saturated the unstandardised RBF bandwidth at `652.6` vs. `0.63` standardised, compressing distance dynamic range by `47x`).
- Compute `LOCATION` and `SCALE` **strictly inside `STABLE_PERIOD`**, persist `_STDSTAT_<id>`, and apply `method=in(...)` in Step 3 (never re-standardise Step 3 on its own scoring window!).
- Always join scores back to **raw unstandardised engineering units** before fitting/scoring the `PROC GRADBOOST` TreeSHAP explainer and publishing `TS_TRANS_*` so sensor plots remain human-readable (°C, kPa, kW).

### 3. Frozen Baseline Threshold + Graded Severity vs. Collapsed Autocorrelated `PROC SPC` Limits
- High-frequency telemetry has lag-1 score autocorrelation $\approx 0.98$; `PROC SPC irchart` estimates $\hat{\sigma}$ from moving ranges, collapsing control limits 17–25× too tight and flagging normal plateaus as alerts. Meanwhile, recomputing control limits in Step 3 judges the test window against itself!
- **Canonical Fix:** Keep `PROC SPC` solely for Western Electric / Nelson `_TESTS_` pattern flags, and drive warnings from:
  - **Frozen Baseline Threshold (`THRESH_*`):** `R2_SVDD` (`PROC SVDD` `TrainingResults RowId="THRESH"`), `P99` of training `_Anomaly_` (`ISOLATION_FOREST`), or `P95/P99/P99.5/P99.9` of training `_MTS_INDEX_` (`MTS_SIMPLE`). Never recomputed in Step 3!
  - **Frozen Scaling Ceiling (`DMAX_*`):** Persisted alongside `THRESH_*` in `GIMPORTANCE`/`STDSTAT`. For quadratic scores (`MTS_SIMPLE`), cap `DMAX_MTS = min(max, max(P99.9, 2.5 * THRESH_MTS))` so single-sample MD spikes cannot compress genuine warnings down to `Watch`.
  - **Margin & Persistence Rule:** `MARGIN = min(1, max(0, (score - THRESH) / (DMAX - THRESH)))`; map `<= 0.25` → `1 (Watch)`, `<= 0.60` → `2 (Warning)`, `> 0.60` → `3 (Alarm)`. Require `WARN_RUNLEN >= 1` (`3` default, persisted from Step 2 to Step 3; `min=1` in UI `NUMERICSTEPPER`) consecutive samples before escalating `Watch` → `Warning`/`Alarm`.

### 4. Condition-Number Ridge Stabilization & Exact Additive Attribution (`MTS_SIMPLE`)
- Scale Mahalanobis distance by sensor count: $\text{MTS\_INDEX}(t) = \sqrt{\max(0, z_t^\top P z_t) / p}$ (expected healthy mean $\approx 1.0$, independent of $p$).
- Enforce ridge floor $\lambda_{\min}(R + \lambda I_p) \ge \max(10^{-6}, \lambda_{\max}(R) / 10^4)$ ($\kappa \le 10^4$) in `PROC IML` so collinear sensors cannot invert noise into unbounded weights.
- Decompose exact signed feature contributions without needing a TreeSHAP surrogate:
  $$C_{t,j} = \frac{z_{t,j}\,(P z_t)_j}{p \cdot \max(\text{MTS\_INDEX}(t), 10^{-12})}, \qquad \sum_{j=1}^p C_{t,j} = \text{MTS\_INDEX}(t)$$

### 5. Methodological Paradoxes (`Docu/Anomaly.md` & `ANOMALY_SUITE_PLAN.md`)
- **Single-Arity vs. `CoMuT` Paradox (Wenig et al. 2024):** Univariate channel-wise detectors aggregated with `MAX_AFTER` beat multivariate models on single-sensor faults (`n=1`) and avoid their ~36% numerical crash rate, yet collapse (`PR-AUC 0.016` vs. `0.622`) on pure cross-channel correlation breaks (`CoMuT`, `n >= 2`). Pair a fast univariate `MAX_AFTER` anchor with multivariate correlation/subspace detectors (`SVDD`, `ROBUST_PCA`, `MTS`, `SENSOR_GRAPH_GDN`).
- **Avoid `PA-F1` Benchmark Illusion (Wu & Keogh 2021):** Never rely on Point-Adjustment F1; test candidate detectors against trivial rolling-SD / IQR baselines.

---

## 3. Live-Profiled Performance Optimization Rules (`[VERIFIED]`)

Measured on `SVDD_5_min_mean` (`Chiller 18B`, `45,779` training timestamps × `14` sensors = `640,906` transposed rows):

| Bottleneck | Measured Cost | High-Impact Fix |
| :--- | :--- | :--- |
| **`PROC GRADBOOST ... crossvalidation kfold=5;`** when only `VariableImportance` & `AST2` (`TREESHAP 1`) are kept | **`26.22s`** (33% of `79.1s` Step 2!) | Drop `crossvalidation kfold=5;` unless CV holdout metrics are explicitly published — full-data `AST2` and `VariableImportance` stay identical while cutting ~21–22s per asset. |
| **Compute-side `SORT` / `TRANSPOSE` / `STDIZE` / `CORR`** moving hundreds of thousands of rows out of CAS | `~5–8s` Step 2; Step 3 `STDIZE` = `2.64s` over all `137,337` rows before filtering `16,664` | Push `VARSCREEN` (`simple.correlation` + `simple.summary`), `STDIZE`, `BY`-group severity `DATA` steps, and sensor/SHAP unpivots (`do _i = 1 to dim(_v); ... output; end;`) into 8-worker CAS `DATA` steps; filter Step 3 by `PAM_ASSET_ID` & `&G_TIME_FILTER.` **before** standardising/joining (`8.2x` fewer rows). |
| **VA Tab 2/3 `<ScatterPlot>` circles & Tab 1 `6`-query fan-out over `TS_TRANS`** | `vi92`/`vi314` SVG = **`4.30 MB`** (`45,780` `<circle>`s, `92k` lines); Tab 1 runs `6 × 640k` queries (`2.73 MB` SVG) | Separate a **1-row/timestamp** series table (`45k` rows) for Tab 1 & `DATETIME` prompts, delete dead `<DataDefinition>`s inside `synchronized` blocks, slim `TS_TRANS` from `31` cols to the 5–6 columns needed by Explainers, drop `_INTERCEPT_` rows from `TS_SHA_T` before CAS load, and omit `display="ALL"` markers on 45k-point `<SeriesPlot>`s. |
