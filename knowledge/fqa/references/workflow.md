# Investigation workflow

## Contents
- Entry paths
- The 4-question Early Warning thought process (BP 9)
- Step-by-step (alert-driven — Special Cause)
- Data-selection-driven entry
- Common Cause discovery workflow (chronic issues not flagged by EI)
- Proactive monitoring of known product/process changes (BP 11)
- Monitoring closed issues & CAPA verification (BP 6)
- Choosing the next step
- Stop criteria and result
- Onboarding a new tenant

## Entry paths

| Entry | Starts at | Typical question |
|---|---|---|
| Alert-driven (Special Cause) | an Emerging Issues alert | "Why is model × component in alert?" |
| Data-selection-driven | a saved data selection | "What is going on in this population?" (you already know roughly where to look) |
| Common Cause screening | a 12–18m in-policy model cohort | "Which chronic, stable high-rate components are costing us money without triggering an EI spike?" |
| Proactive change monitoring | a combined DS (old + new product/supplier) | "Did our new product launch, supplier change, or cost-reduction modification introduce early-life issues?" |
| Triage digest | all alerts of the in-scope runs | "Which alerts should we look at today?" |

## The 4-question Early Warning thought process (BP 9)

Whenever triaging an early warning alert, structure the investigation around four sequential questions:
1. **What is normal (before the alert)?** Establish baseline reliability, historical failure rate by MIS (Baseline Chart), and baseline Weibull shape parameter $\beta$.
2. **What is the current situation?** Measure the alert period failure rate, inspect the cell **Details Chart** (actual blue curve vs. critical red curve across sales-lag periods), and fit the current Weibull $\beta$.
3. **Is the change relevant (statistically and commercially)?** Check two things: (a) Do the Weibull $\beta$ **confidence intervals** of the baseline builds and alert builds **not overlap**? (Non-overlapping CIs confirm a statistically significant shift in failure mode/acceleration). (b) What is the **projected failure rate at the warranty limit** (e.g. 12m / 24m) and B-life (`Time to 1/5/10/20/25 Pct Failure`)?
4. **What is different?** Use Pareto, Statistical Drivers, Decision Tree, Geographic, Trend & Control, Failure Relationships, and Text Mining to isolate the physical or operational difference.

## Step-by-step (alert-driven — Special Cause)

### 1. Triage
- Pull the alerts of the completed EI run(s); key them by `run | breakout | AlertID`.
- Rank by `score`, `cost_score`, or `Acceleration-Alert Period` (LTS 2026.09+); also review `Events-Alert Period`, `Alert Duration (Months)`, and `Time To 1/5/10 Pct Failure`. Keep the top K (default 10).
- For each, read the pattern (see interpretation.md § Chart patterns) and apply the **3-step False Positive screen (BP 4)**:
  1. Check the run's sensitivity ($\sigma$ setting: $1\sigma \approx 15.87\%$ false positive rate vs. $2\sigma \approx 2.28\%$ vs. $3\sigma \approx 0.13\%$).
  2. Inspect the cell **Details Chart** (3rd time dimension: *Sales Period Since Production*) of the red alert cell **and adjacent non-alert cells** (above/below/left/right). If the blue actual line barely touches the red critical line and surrounding cells have zero events, treat with caution.
  3. Flag **window-edge** alerts (start in the first 2 months of the monitoring window) → likely `data_artifact` unless ranked high; flag **small n** (few events).

### 2. Scope the subset (BP 2 — Alert vs. Non-Alert comparison)
- Build 2–4 candidate cell sets with unit and claim counts, e.g. alert cells only;
  alert + previous 3 build periods; alert + same TIS in all builds.
- Default: **select the alert cells plus the surrounding/preceding non-alert build cells** as baseline (`Analyze Subset`). FQA automatically creates the system variable `Alert` (`0` = non-alert baseline, `1` = alert) so downstream nodes can set `Group Variable = Alert`.
- Materialize with an `alert` 0/1 flag. Minimum: 500 units and 20 claims.
- Define the **alert-defining population** explicitly: units in the alert build periods with a
  claim on the alert breakout (e.g. primary part = alert part). Coverage is measured against it.

### 3. Normalize (phase 4 — run it now, not last)
- Early-life rate of the alert-defining event **by build month**: share of units with a first
  event within 30 and 90 days of build (or Trend & Control with `Maximum Exposure = 1 month` and `3 months`, `Adjusted` method — BP 5). Flag months with < 90 days of exposure at the refresh
  date as **immature** and don't use them as evidence.
- `step_month`: first build month whose 90-day rate exceeds the baseline by ≥ 3×.
- **Weibull β CI overlap test (BP 3 & 4)**: Fit Weibull Reliability on alert build columns vs. prior baseline build columns (keeping all censored survivors). If the $\beta$ confidence intervals **do not overlap**, the acceleration/failure-mode shift is statistically significant.
- Template: `templates/fedsql/early_life_by_build_month.sql`.

### 4. Describe (phase 1)
- Pareto of primary labor code (and part/failure code) grouped by `alert`, with a
  Poisson excess test per bar (Bonferroni over levels). Too many levels (> 50) → aggregate to
  the code group and report both.
- Summary tables: top codes × build month, model.
- Label each notable bar *expected* (matches the alert breakout by description), *surprising*
  (not a match, rises in alert vs. baseline) or *baseline shift*. A flat distribution =
  `weak_signal`.

### 5. Drivers and segmentation (phase 2)
- Statistical Drivers (ANOM decision limits) over the mart variable dictionary, **stratified by build quarter**. A
  driver whose effect disappears within strata is confounded with production period.
- Use the top non-confounded drivers to **order** the relationship domains (never to exclude
  one) — see failure-relationships.md § Domain routing.
- Decision Tree when you need an explicit filter for a sub-population (recall narrowing).
- **Note how narrow Phase 2 leaves get:** A Decision Tree leaf or multi-filter drill often narrows the cohort from >1M fleet units $\to$ ~13k alert units $\to$ ~25 units / 7 claims. While ideal for defining a containment rule, **this narrow population pins key variables to 1 level and is too small for Phase 3 context building.**

### 6. Relate & Mine Text Context (phase 3 — WIDEN THE POPULATION FIRST!)
- **Crucial Population Expansion Step**: Do **not** run Failure Relationships or Text Mining on a small Phase 2 subpopulation (e.g. a 25-unit Decision Tree leaf). In such a tight slice, key attributes are already fixed to a single or tiny number of levels (preventing any cross-level contrast) and $N$ is too small for SVD topic clustering or association rule support/lift. Step back up to a wider parent cohort before running Phase 3:
- **Failure Relationships**: Run on the **model/series-level cohort of the scoped build periods** (alert + baseline periods, **all parts/codes — remove the single-part event filter**). Never on the alert part alone, never on a tiny Phase 2 leaf, and never on full model history.
  - Unit-level: first antecedent claim → first consequent claim on the same unit, 90-day window (`max_inter_oc_time = 3`), direction `before` (and `after` if the Pareto finding calls for it), or `max_inter_oc_time = 0` for same-claim co-occurrence.
  - Keep pairs with support ≥ 10 units, confidence ≥ 0.2, lift ≥ 2.0 (lift vs. the consequent's unit rate in the same cohort).
  - For every surviving pair compute its **coverage** of the alert-defining units.
  - Pick at most 2 pairs to drill, preferring pairs whose antecedent was a *surprising* Pareto bar.
- **Text Mining**: Run on a **widened parent subset** (e.g. across alert + baseline build quarters, or across all damage codes for the subsystem, checking both `CLAIM` comments and `SSD` tickets) where the reporting variable (such as `Production Quarter`, `Damage Code`, or the `Alert` flag) still has multiple populated levels with sufficient contrast.

### 7. Drill (narrow population)
- Return to the narrow cohort (units with both relationship codes, or the tight Phase 2 Decision Tree leaf); run the **Detail report**; read `TECH_COMMENT` and `CSTMR_COMMENT`
  separately (≥ 15 non-missing comments per field, else "insufficient text").
- Summarize themes with supporting comment IDs and a share bucket (most / some / few); judge
  consistency. Generic "replaced part" comments don't count as support.
- If themes are thin or inconsistent → enable **Find Similar Contents** on exemplar comments or inspect the Text Mining clusters on the widened parent subset.

### 8. Hypothesize
- One or more hypotheses, each with mechanism class, **role** (primary / contributing),
  coverage, confidence, supporting and contradicting findings, and gaps.
- Coverage < 0.25 → contributing. If nothing reaches 0.25, say "the alert is not yet
  explained" and describe the largest uncovered segment.
- Confidence *high* only with ≥ 3 supporting findings from ≥ 2 analysis types including the
  drill; weak-signal findings don't count.
- Recommended actions: `narrow_recall_population`, `request_part_returns`,
  `draft_service_bulletin`, `monitor`, plus UI instructions for assign/stage/share and an
  optional `create_project` write-back (approval).

## Data-selection-driven entry

1. Read the DS (`get_data_selection_details`), resolve rolling periods against the refresh date,
   ignore the description as evidence.
2. Explore: text mining per comment field; geographic if geo variables exist.
3. Segment: decision tree and/or trend by exposure.
4. Continue with drivers / relate / drill as above if a target code emerges (remembering to widen back out if Phase 2 narrows the population before running Phase 3 Failure Relationships or Text Mining).

## Common Cause discovery workflow (chronic issues not flagged by EI)

Emerging Issues is designed to catch **Special Cause** variation (unplanned anomalies from specific design, supplier, or process changes, typically detecting them 3–4 months / ~121 days earlier than manual tracking, including far down the "Extended Pareto" tail). However, **Common Cause** issues—inherent, stable, predictable high failure rates "hiding in plain sight"—do not trigger EI alerts because there is no sudden statistical spike relative to baseline.

Use the **7-step Common Cause workflow** to uncover and prioritize chronic warranty drivers:
1. **Create a Data Selection** covering 12–18 months of recent in-policy warranty data for a model family.
2. **Run a Pareto Analysis** using the **Unadjusted** failure rate (or cost rate) as the analysis variable, and the component / object code (one hierarchy level above raw part number) as the reporting variable.
3. **Select Top Components → "Analyze Separately"**: Select the top 10+ bars (or up to 25 bars) and launch a **Weibull Reliability Analysis** using **Analyze Separately** so FQA fits a dedicated Weibull curve for each component.
4. **Compile the 4-Metric Screening Table**: For each component, record:
   - Current **Unadjusted Failure Rate**
   - **12-Month Projected Failure Rate** (from Weibull fit)
   - **24-Month Projected Failure Rate** (or full warranty period projection)
   - **Weibull Shape Parameter ($\beta$)** (acceleration rate)
5. **Assess against the Acceptable Failure Rate & Acceleration Matrix**:
   | Is Projected Rate Acceptable? | Is Acceleration ($\beta$) Acceptable? | Diagnosis | Priority |
   |---|---|---|---|
   | **Yes** (low rate) | **Yes** ($\beta \le 1$) | Healthy / under control | **Low** |
   | **Yes** (currently low) | **No** ($\beta > 1$, accelerating fast) | **Early-stage Special Cause** (growing rapidly toward a problem) | **Medium / High** |
   | **No** (chronically high) | **Yes** ($\beta \approx 1$, stable/non-accelerating) | **True Common Cause Issue** (chronic baseline cost/failure driver) | **Medium** (target for engineering redesign / cost reduction) |
   | **No** (high rate) | **No** ($\beta > 1$, accelerating) | **Late-stage Special Cause** | **High / Urgent** |
6. **Prioritize & scope projects** on the Medium/High components.
7. **Execute Phase 2 & Phase 3 RCA** (Drivers, Decision Tree, Failure Relationships, Text Mining) to isolate actionable engineering improvements.

## Proactive monitoring of known product/process changes (BP 11)

When engineering introduces a **new product launch**, **supplier change**, **manufacturing process change**, or **component cost reduction**, do not wait passively for batch EI runs. Choose from four proactive monitoring setups:

1. **Combined Data Selection (Old + New Product/Component)**: Create two simple Data Selections (DS 1 = predecessor model/component as historical baseline; DS 2 = new model/component) and union them with **Combine Data Selections**.
2. **Compare the 4 Proactive Methods**:
   - **On-Demand Alert on Combined DS**: Uses the predecessor product's historical rates to establish expected critical values for the new product, flagging early statistical excess cell-by-cell.
   - **Threshold Alert on New DS**: Best when no predecessor product exists and engineering has a fixed target ceiling (use `Adjusted` or `Extrapolated` calculation method so young builds are evaluated fairly).
   - **Early-Life Trend & Control (BP 5)**: Run two Trend & Control charts on the combined selection with **`Maximum Exposure = 1 month`** and **`Maximum Exposure = 3 months`**, `Calculation Method = Adjusted`, and `Analysis Variable = Failure Rate` to catch infant mortality shifts immediately.
   - **Grouped Exposure Analysis**: Run Exposure Analysis on the combined selection with **`Group Variable = Model / Change Flag`** to visually overlay the new cohort's cumulative failure curve against the predecessor curve across Time in Service.

## Monitoring closed issues & CAPA verification (BP 6)

After a corrective action (CAPA / clean point) is implemented in production or the field, verify resolution across **four complementary views**:
1. **Emerging Issues Heat Map**: Disappearance or cooling of red alert cells in build columns after the clean-point date. Also check **Automatic Alert Reconciliation**: because FQA reconciles active alerts across weekly runs within the `Alert Gap` window (carrying forward status/comments and expanding `Alert End Date` only while the issue remains active), an open alert whose **`Alert End Date` stops advancing and falls behind the current run date** indicates the issue is no longer active in new builds.
2. **Before vs. After Pareto**: Grouped by pre-clean-point vs. post-clean-point builds, confirming a sharp drop in the target object/part code.
3. **Trend & Control Chart**: Confirming the post-clean-point build months drop back inside the pre-issue control band (and pass all 3 control tests).
4. **Before vs. After Weibull Reliability**: Confirming a lower projected failure rate at warranty maturity and a flattened slope ($\beta$) for post-CAPA builds.

## Choosing the next step

When the current evidence doesn't settle the question, choose from actions whose preflight
passes. Fallback priority when unsure:

1. `trend_by_exposure` — find the onset.
2. `decision_tree` — narrow the population.
3. `geographic` — check regional concentration (often a negative control).
4. stop.

Cap the loop (default 4 extra steps) and the budget (default 14 analyses per investigation).
State in the result when a budget cut the investigation short.

## Stop criteria and result

End in one of: hypothesis found, inconclusive, aborted (auth / error / budget without
evidence). The report contains: executive summary, trigger and pattern, evidence chain
(analysis → key numbers → finding, each citing its source), hypotheses with coverage and gaps,
recommended actions and their approval status, limits (skipped analyses with preflight reasons,
immature months, weak signals), and the project tree to recreate in the UI.


## Onboarding a new tenant

Produce a tenant profile (see `tenants/reference/tenant-profile.yaml` as the template):

1. Discover tables and row counts (data-model.md § Onboarding checks).
2. List in-scope EI runs; resolve and pin each run's WMEXT/WUMKR hash; check WMEXT rows = alert total.
3. Build the variable dictionary from mart columns (business name → column, dimension, label, type).
4. Read the data refresh date.
5. Measure PART/LABOR line coverage and comment coverage per field.
6. Test the FedSQL traps (date literal, derived-table grouping, date difference).
7. Record the write-back sandbox folder ID.
8. Pin golden values for one known alert so regressions are detectable.
