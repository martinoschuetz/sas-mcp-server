# Interpreting FQA results

Domain priors for reading statistical output. They guide judgment; they never replace a number
computed in SAS.

## Contents
- Chart patterns → mechanism classes
- Early life and Weibull β
- Pareto: expected, surprising, weak
- Relationships: support, confidence, lift, scope
- Coverage: explaining the alert
- Drivers and confounding
- Comments and text clusters
- Artifacts and small numbers
- Mechanism classes
- Wording

## Chart patterns → mechanism classes (BP 1b)

| Pattern | Looks like | First suspects |
|---|---|---|
| `recent_build_early_tis` | build chart: red cells in recent build months, early months in service | production change, supplier change, plant incident |
| `right_angle_pattern` | build chart: red cells form a right-angle / L-shape or diagonal wave across build months × TIS | **field or calendar-driven event** (e.g. seasonal weather or a service campaign hitting older builds at high TIS and newer builds at low TIS simultaneously) |
| `single_build_period` | one build month (or short run) elevated at all TIS | batch/lot defect, line stoppage, one-off assembly error |
| `horizontal_band` | red cells across many build months at the *same* TIS row (e.g. 12–15 MIS) | wear-out mode at a predictable age, or scheduled maintenance/inspection interval triggering repairs |
| `event_spike` | event chart: one calendar month elevated across builds | seasonal weather, service-action side effect |
| `event_step` | event chart: sustained rise from a calendar month | new service procedure, parts change in the field, policy change |
| `diffuse` | many scattered cells | usage/wear, data artifact, low signal |

## Early life, Weibull β, and the False-Positive Verification Test (BP 3 & BP 4)

- Early-life rate = share of units with a first failure within 30 / 90 days of build, by build
  month. A **step** by build month + high early-life ratio = production-side defect.
- Weibull shape β (reliability analysis):
  - β < 1 → infant mortality / assembly or supplier defect (failure rate decreases over TIS).
  - β ≈ 1 → random or environmental failures (constant hazard rate).
  - β > 1 → wear-out / fatigue (failure rate accelerates over TIS; $\beta = 2$ means linearly increasing hazard, $\beta > 3$ means rapid wear-out).
- **3-Step Verification to Separate True Issues from False Positives (BP 4):**
  1. **Check Sigma ($\alpha$) Sensitivity**: At $1\sigma$, ~15.87 % of cells can cross threshold by chance; at $1.5\sigma$, ~6.68 %; at $2\sigma$, ~2.28 %; at $3\sigma$, ~0.13 %.
  2. **Inspect the Cell Details Chart (3rd Time Dimension: Sales Lag) & Neighbors**: Click the red cell to compare actual events (blue) vs. critical value (red) across *Sales Period Since Production*, and inspect the Details Charts of **adjacent non-alert cells** (left, right, above, below). If the blue line barely touches the red line at a single point and neighboring cells have zero claims, it is likely a random spike. If adjacent cells show building pressure just below the red critical line, the issue is real.
  3. **Weibull $\beta$ Confidence Interval Overlap Test**: Run Weibull Reliability comparing the alert build columns against prior non-alert baseline build columns. Check the 95 % confidence intervals for $\beta$ (and the projected failure rates at the warranty limit, e.g. 12m/24m):
     - **Confidence intervals do NOT overlap** → statistically significant shift in failure behavior (confirmed Special Cause).
     - **Confidence intervals overlap heavily** → acceleration has not significantly changed; verify whether scale ($\eta$) or projected warranty rate shifted before escalating.
- A build month needs ≥ 90 days of exposure at the refresh date before its 90-day rate means
  anything. Immature months look *good* (few claims yet) — never read them as recovery.
- **Common Output Elements — Sample Size Rule (Product vs. Event Attributes):**
  - When a results table (Pareto, Summary Tables, Statistical Drivers) reports on a **Product attribute** (e.g. `Production Year`, `Model Code`, `Selling Dealer`), the **Sample Size varies across rows** because each row's denominator is only the units possessing that product attribute.
  - When a results table reports on an **Event attribute** (e.g. `Primary Labor Code`, `Replaced Part Code`, `Repairing Dealer`), the **Sample Size is constant across all rows** (equal to the total population at risk in the Data Selection), because any unit in the fleet *could* potentially experience any event type.


## Pareto: expected, surprising, weak

- **Expected**: the bar matches the alert breakout by description (alert part "cruise control
  cable" → labor "Replace Cruise Control Cable").
- **Surprising**: doesn't match the breakout and rises in rank or share from `alert=0` to
  `alert=1`. Surprising bars become follow-up codes for relationships.
- **Baseline shift**: the whole distribution moves; not one code.
- **Weak signal**: the top bars are close together (e.g. 35, 33, 25, 23, 22 of 75 levels) or the
  Poisson excess test isn't significant after Bonferroni. You may still follow the bar, but mark
  the finding *weak* and don't let it carry a high-confidence hypothesis.

## Relationships: support, confidence, lift, scope

- Support = units with antecedent then consequent within the window. Confidence = support ÷
  units with the antecedent. Lift = confidence ÷ the consequent's unit rate in the **same cohort**.
- **Scope decides the answer.** The same pair can pass on the scoped cohort and fail on full
  history (reference tenant: lift ≈ 28 on the alert cohort, 0.76 on pre-alert builds). Always
  state the cohort next to the numbers.
- A single-part cohort can't contain cross-code sequences — widen to the model-level cohort of
  the scoped build periods.
- Check the reverse direction. Zero reverse sequences strengthen a precursor reading.

## Coverage: explaining the alert

Every mechanism must answer: *how many of the alert-defining units does it explain?*

- coverage = alert-defining units that show the mechanism ÷ all alert-defining units (computed in SAS).
- ≥ 0.25 can be primary; < 0.25 is contributing.
- Reference-tenant lesson: the demo's "battery acid → cable" sequence was real (lift ≈ 28, comment
  support) but covered only 38 of 610 alert units (6.2 %). The alert itself was an early-life step
  in builds from Oct 2019. A real, vivid mechanism can still be a sideshow.

## Drivers and confounding

- Rank drivers **within build-period strata** (quarter). A dealer or region effect that
  disappears within strata is a production-period effect in disguise.
- Driver type suggests where to look for relationships:
  - dealer, customer state, technician → workmanship / repair-induced → LABOR domain first;
  - production period, plant, supplier, model → manufacturing / hardware → PART domain first.
- Heterogeneity that remains within the affected stratum (e.g. dealers inside the step months)
  is a **secondary modifier** — a candidate for a decision-tree follow-up, not a root cause.

## Comments and text clusters

- Read technician and customer comments separately. When they disagree (e.g. tech text about the
  cable, customer text about fuel pressure on the same claims), report a text-to-code mismatch;
  never cite the off-topic field as evidence.
- Themes need cited comment IDs and a share bucket. With few comments, "some" is honest; "most"
  needs the numbers.
- Off-topic noise (dispatch calls, unrelated questions) produces no theme.

## Artifacts and small numbers

- **Window edge**: alerts starting in the first 2 months of the monitoring window are often
  edge effects of the EI statistic (51 of 145 on the reference run).
- **Volume bias**: almost all alerts on one high-volume model is expected, not a finding.
- **Small n**: say "few events (n = …)" in the interpretation; don't rank urgency high on n < ~50
  without other evidence.
- **Multiplicity**: many regions/dealers → some look extreme by chance. Use corrected tests;
  geography is frequently a negative control.
- **Empty output tables** mean "check the run", not "no problem".

## Mechanism classes

`production_change`, `supplier_change`, `plant_incident`, `seasonal_weather`,
`service_action_side_effect`, `usage_or_wear`, `secondary_failure` (one failure damaging another
component), `workmanship`, `data_artifact`.

## Wording

| Evidence | Say |
|---|---|
| association only | "associated with", "consistent with" |
| strong association + mechanism + comments | "strong association consistent with a causal link" |
| high confidence (≥ 3 findings, ≥ 2 analysis types, incl. comments) | "likely cause" / "root cause" allowed |
| coverage < 0.25 | "contributing mechanism", never "root cause of the alert" |
| data can't distinguish plant vs. supplier | "production or supplier change" + owner question + part returns |
