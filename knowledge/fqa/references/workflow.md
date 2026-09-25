# Investigation workflow

## Contents
- Entry paths
- Step-by-step (alert-driven)
- Data-selection-driven entry
- Choosing the next step
- Stop criteria and result
- Onboarding a new tenant

## Entry paths

| Entry | Starts at | Typical question |
|---|---|---|
| Alert-driven | an Emerging Issues alert | "Why is model × part in alert?" |
| Data-selection-driven | a saved data selection | "What is going on in this population?" (you already know roughly where to look) |
| Triage digest | all alerts of the in-scope runs | "Which alerts should we look at today?" |

## Step-by-step (alert-driven)

### 1. Triage
- Pull the alerts of the completed EI run(s); key them by `run | breakout | AlertID`.
- Rank by `score`, show `cost_score` and `events`. Keep the top K (default 10).
- For each, read the pattern (see interpretation.md § Chart patterns) and flag:
  - **window-edge** alerts (start in the first 2 months of the monitoring window) → likely
    `data_artifact` unless ranked high;
  - **small n** (few events) → say so;
  - big gap between rank 1 and rank 2 score → rank 1 dominates.

### 2. Scope the subset
- Build 2–4 candidate cell sets with unit and claim counts, e.g. alert cells only;
  alert + previous 3 build periods; alert + same TIS in all builds.
- Default: **alert cells plus the preceding build periods** as baseline (the demo pattern).
- Materialize with an `alert` 0/1 flag. Minimum: 500 units and 20 claims.
- Define the **alert-defining population** explicitly: units in the alert build periods with a
  claim on the alert breakout (e.g. primary part = alert part). Coverage is measured against it.

### 3. Normalize (phase 4 — run it now, not last)
- Early-life rate of the alert-defining event **by build month**: share of units with a first
  event within 30 and 90 days of build. Flag months with < 90 days of exposure at the refresh
  date as **immature** and don't use them as evidence.
- `step_month`: first build month whose 90-day rate exceeds the baseline by ≥ 3×.
- Weibull β alert vs. baseline, if the reliability preflight passes.
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
- Statistical Drivers over the mart variable dictionary, **stratified by build quarter**. A
  driver whose effect disappears within strata is confounded with production period.
- Use the top non-confounded drivers to **order** the relationship domains (never to exclude
  one) — see failure-relationships.md § Domain routing.
- Decision Tree when you need an explicit filter for a sub-population (recall narrowing).

### 6. Relate (phase 3)
- Failure Relationships on the **model-level cohort of the scoped build periods** (alert +
  baseline periods, all parts). Never on the alert part alone, never on full model history.
- Unit-level: first antecedent claim → first consequent claim on the same unit, 90-day window,
  direction `before` (and `after` if the Pareto finding calls for it).
- Keep pairs with support ≥ 10 units, confidence ≥ 0.2, lift ≥ 2.0 (lift vs. the consequent's
  unit rate in the same cohort).
- For every surviving pair compute its **coverage** of the alert-defining units.
- Pick at most 2 pairs to drill, preferring pairs whose antecedent was a *surprising* Pareto bar.

### 7. Drill
- Subset to units with both codes; run the detail report; read `TECH_COMMENT` and `CSTMR_COMMENT`
  separately (≥ 15 non-missing comments per field, else "insufficient text").
- Summarize themes with supporting comment IDs and a share bucket (most / some / few); judge
  consistency. Generic "replaced part" comments don't count as support.
- If themes are inconsistent → broaden (similar comments, text mining on the parent subset).

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
4. Continue with drivers / relate / drill as above if a target code emerges.

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
