# Statistical Drivers

**Phase 2 — Segmentation.** Ranks categorical variables by their main effect on the elevated
claim rate. A dimensionality-reduction step before the decision tree and before choosing the
Failure Relationships domain.

## When
After the descriptive phase, to learn *which kind* of variable drives the excess:
production-side (build period, model, plant, supplier) or field-side (dealer, region, technician).

## Parameters & ANOM Mechanics
Native: `run_statistical_driver_analysis_tool`. Candidates must exist in the mart variable
dictionary (not just the DS profile).

FQA's Statistical Drivers node uses **Analysis of Means (ANOM)** to test whether specific levels
of each candidate reporting variable deviate significantly from the overall population mean:
- **Summary Table**: Ranks candidate variables and flags `Decision Limit Exceeded` as **`Yes`**,
  **`No`**, or **`NA`**.
  - **`NA` occurs when a variable has fewer than 2 distinct levels** (e.g. already pinned to 1
    value by the Data Selection filter) **or more than 500 distinct levels**.
- **ANOM Decision Charts (Varying vs. Constant Decision Limits):**
  - **Product Attributes (Varying Decision Limits):** When evaluating a product attribute (e.g.
    `Model Code`, `Production Month`, `Plant`), each level has a *different* number of units in its
    denominator. Because **smaller sample sizes produce wider decision limits** (and larger sample
    sizes produce narrower limits), the upper and lower decision limit lines step up and down
    across the levels of a product attribute.
  - **Event Attributes (Constant Decision Limits):** When evaluating an event attribute (e.g.
    `Primary Labor Group`, `Claim Status`), every level shares the *same* total fleet denominator
    (since any unit could experience any event type), producing **flat, constant upper and lower
    decision limits** across all levels.
- **Effect of `Alpha` ($\alpha$):** Default is `0.05`. Making `Alpha` smaller (e.g. `0.01`)
  **widens the decision limits**, requiring a larger deviation from the mean to flag a level as
  statistically significant (fewer `Yes` flags). Making `Alpha` larger narrows the limits.

Prune collinear candidates before running. Keep **one** time field (build month, engine build
month, delivery month and registration month all encode the same thing), one of each
geography pair, and drop anything *current* rather than as-built — a "current engine type" or
current odometer reflects post-repair state and leaks the outcome. Drop unit-unique identifiers
(VIN, engine number, gearbox number) and anything the data selection already pins.

## Evidence (templated)
Per candidate: rate by level, χ² test overall **and within build-quarter strata**. A driver is
`confounded_with=production_period` when its within-strata p ≥ 0.01 or it shows no effect in
pre-step strata.

## How to stratify
The analysis node has **no stratification parameter**. Three ways, cheapest first:

1. **Cross-tab the top drivers.** Run drivers once, take the top 3–5, then build a summary table
   of each against production quarter with the rate in the cells. A level that is worst in every
   quarter is a general risk factor; one that only separates from the alert window is the change
   candidate. This is the confounding test you actually need and it costs one table per driver.
2. **Repeat the cell selection per quarter.** Select one quarter's build-month columns at the
   same service-period rows, subset, and re-run. Compare *ranks* across quarters rather than
   p-values, since the populations differ in size.
3. **Take it out of the workspace** when the statistic must be defensible: query units, claim
   flag, build quarter and the candidate, then run a proper stratified test in SAS.

Event counts collapse as you cut to one quarter, so check them before investing in option 2.

## Interpretation
- Top non-confounded driver type sets the **order** of relationship domains
  (failure-relationships.md § Domain routing).
- A dealer spread that vanishes within strata is a build-period effect. Heterogeneity that
  remains inside the affected stratum is a secondary modifier (reference tenant: χ² = 68.4,
  df = 34 among dealers within Oct–Nov builds) → decision-tree follow-up, not a workmanship root cause.
- **Read the absences.** Which variables did *not* reach significance is often the stronger
  finding. Plant and assembly line absent argues against a site-specific workmanship problem and
  points at a specification change that reached every site at once. Say so explicitly rather
  than only listing what passed.
- Group the surviving drivers by *kind* before interpreting: time fields, specification fields,
  configuration fields, commercial fields. A list dominated by powertrain specification plus a
  regulatory limit, with build timing behind it, reads as a respecification. Regulatory limits
  change on fixed dates, so an emission or homologation field is a build-date proxy as much as
  a technical one.
- Stratification cannot separate two things that moved together. If one plant changed supplier
  in the same month and nothing else changed, plant and build period are the same variable in
  your data, and only as-built component evidence resolves it.

## Pitfalls
Unstratified drivers on a build-period step light up every variable correlated with build date
(dealer allocation, region). Earlier ad-hoc work on the reference tenant wrongly named the
selling dealer as root cause this way.
