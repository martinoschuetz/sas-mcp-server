# Population scoping: which data for which analysis

The most common way to get a wrong answer in FQA is not a bad parameter. It is running the
right analysis on the wrong population. Each analysis needs a different slice, and the slice
that is correct for one is degenerate for the next. Decide three things separately for every
node.

## Contents
- The three axes
- Per-analysis scoping table
- Why Phase 3 requires widening the population (the "fixed variable levels" trap)
- Never condition on the outcome
- Analyses that need elapsed time
- Calendar time is not age
- Equalizing exposure with cell selection
- Censoring, reporting lag, and Maximum Exposure vs. Maturity Level

## The three axes

| Axis | Question | Set by |
|---|---|---|
| **Units** | Which vehicles form the denominator | Product-level filters: model, series, build window, configuration |
| **Events** | Which claims count as the outcome | Claim-level filters: object code, damage code, warranty type |
| **Observation window** | How much life of each unit you can see | Time-in-service rows, or the build window's age at the refresh date |

An alert-derived data selection sets all three at once and usually too tightly. Treat it as a
starting point, not as the population.

The event filter is the one people forget is separable. Filtering to one object code does not
remove any units, because the filter sits on the claim. The units without that claim stay in
the denominator, which is what you want for a rate and what you need for censoring.

## Per-analysis scoping table

| Analysis | Units | Event filter | Window |
|---|---|---|---|
| Pareto | Alert cells plus matched baseline cells | **Keep.** The reporting variable drills inside the alert's own component | Fixed, narrow |
| Geographic | Same as Pareto | Keep | Fixed, narrow. See the delivery-lag trap below |
| Exposure, Trend | Build months across the step | Keep | Wide on age, that is the axis |
| Statistical Drivers | Affected and unaffected builds together | Keep | Fixed service-period rows, so builds are comparable |
| Decision Tree | Same as drivers, restricted to units that reached the target window | Keep | Fixed, and every unit must have had the chance to fail |
| Text Mining | **Widen back out** from Phase 2 leaves so reporting variables are not pinned to 1 level | Keep (or widen to subsystem), and check which domain (`CLAIM` vs `SSD`) holds the narrative | Any age |
| Failure Relationships | **Widen back out** to a comparable model/series cohort **not** conditioned on having failed | **Remove** single-part/code filter — you need the other claims and multiple levels | Long. Units need months of history |
| Detail report | Tight Phase 2 leaf or relationship unit list | Keep | Narrow — designed for human reading of specific records |
| Reliability | All units of the cohort including survivors | **Keep.** It defines the failure event; survivors are the censoring | Long, with failures spread across ages |
| Event Forecasting | Fleet or product line | Keep | Calendar history, truncated short of the refresh date |

## Why Phase 3 requires widening the population (the "fixed variable levels" trap)

In a standard FQA investigation, each drill step shrinks both the unit count and the diversity of
attribute levels. A typical progression looks like:

1. **Root Data Selection**: ~1,100,000 units, ~285,000 claims across all models, years, and components.
2. **Analyze Alert (EI cell subset)**: ~13,291 units, 40 claims on a single series and object code.
3. **Sub-selection by Production Year**: ~3,740 units, 15 claims.
4. **Decision Tree Terminal Leaf (Phase 2)**: **25 units, 7 claims** showing a very clear, high-purity failure pattern.

At the end of Phase 2, it is tempting to chain Phase 3 **Text Mining** and **Failure
Relationships** directly off that 25-unit Decision Tree leaf or narrow sub-selection. **Do not do
this.** Running context-building analyses on a small, tightly isolated population fails for three
structural reasons:

1. **Key variables are already fixed (pinned) to one or too few levels.** The very splits that
   defined the Phase 2 subpopulation (e.g., `Series = X`, `Production Year = 2022`, `Engine = Y`,
   `Emission Limit = Z`, `Object Code = A`) have locked those variables to a single value (or 1–2
   levels). When you run **Text Mining** or **Failure Relationships** to build context, there is
   no variation left in the reporting variables: you cannot see whether a text topic is unique to
   the failing cohort vs. older builds, nor whether a failure sequence is specific to one engine
   or dealer group, because every record in the subset shares the same pinned level.
2. **Sample size ($N$) is too small for unsupervised topic or rule extraction.** Text Mining uses
   Singular Value Decomposition (SVD) and k-means clustering; on 7–15 claims it merely splits
   individual sentences into noisy fragments. Failure Relationships uses association rule mining
   (Support, Confidence, Lift); on a handful of units, support counts fall below minimum
   thresholds and produce either `nosequencesfound_warning` or spurious rules driven by 1–2 trucks.
3. **Narrow event filters eliminate the surrounding context.** An alert or leaf filtered to one
   part or object code strips away all upstream precursor repairs and downstream collateral claims
   on those same vehicles.

**How to build context properly in Phase 3:**
- **For Text Mining**: Step back up to a broader parent population (e.g., the model/series cohort
  across both alert and non-alert production periods, or across all damage codes for that
  subsystem). Run Text Mining on the larger corpus so SVD forms robust symptom clusters, and pick
  a **reporting variable that still has multiple active levels** (such as `Production Quarter`,
  `Damage Code`, `Alert` 0/1 flag, or a binary flag representing the Decision Tree rule) to see
  how symptom themes shift between the baseline and the affected cohort.
- **For Failure Relationships**: Step back to the **model/series-level cohort across the scoped
  build periods (alert + baseline)** and **remove the single-part/single-object-code event
  filter** so all claims on those vehicles are visible. Mine the rules across the broader
  population, then filter or inspect the resulting link graph for rules where your target failure
  code appears as the consequent (to find precursor/root-cause repairs) or antecedent (to find
  collateral damage).
- **For the Details Table**: Keep the tight 25-unit / 7-claim Phase 2 leaf! Reading raw
  unaggregated technician comments one by one is the exact job the narrow leaf is meant for (and
  if you find a telling phrase, you can use **Find Similar Contents** on the wider parent selection
  to see how often that exact narrative appears across the broader fleet).

## Never condition on the outcome

Restricting units to those that already had the claim of interest breaks two analyses in ways
that still produce output.

- **Failure Relationships.** Lift is confidence divided by the consequent's base rate in the
  cohort. If every unit has the alert claim, that base rate is 1.0, lift collapses to
  confidence, and the statistic that separates a real sequence from two common events stops
  working. Generate rules against the full comparable population, then filter the output to
  rules involving the code you care about.
- **Reliability.** The censored survivors are the data. A cohort of only failed units has no
  suspensions, so the fit sees a 100 % failure population and the shape parameter is nonsense.

## Analyses that need elapsed time

Sequence mining and distribution fitting both need units that have lived long enough to show a
pattern. An alert on recent builds at one or two months in service cannot support either, no
matter how the data selection is written. A unit in service six weeks has had one claim, so
there is no chronology, and every observation is censored at nearly the same early age, so
there is no spread for a shape parameter.

Three ways through, in order of preference:

1. Run on an older cohort of the same configuration, if that configuration predates the alert.
   This is the ideal and it is also a test: if no older units share the configuration, the
   configuration itself is new, which is a finding.
2. Run on an earlier cluster of the same component, if the chart shows one. Units that failed a
   year ago are fully observable and preview where the new ones are heading.
3. For the alert cohort itself, do not run the analysis. List the claims directly and read them.
   A few dozen units at low age fit on one screen, and that is more reliable than a statistic
   computed on almost no observation time.

Say which of these you did. A chain learned from older units describes the established failure
mode and may not apply if the new event is a new mechanism.

## Calendar time is not age

Two different time axes run through the mart and mixing them produces confident nonsense.

- **Age** is time in service, the axis of exposure, reliability and the build chart.
- **Calendar time** is the event date, the axis of forecasting and trend by claim month.

Grouping a forecast by build period mixes them, because each build cohort occupies a different
stretch of calendar time and a different maturity. Cohort behaviour by age belongs in exposure,
reliability and time of event. Keep forecasting on calendar time and group it by something that
does not move with age, such as warranty type or product line.

## Equalizing exposure with cell selection

Selecting fixed time-in-service rows across many build-month columns is the cleanest way to make
build months comparable. Every unit is then observed over the same age window by construction,
which is more reliable than setting a maximum-exposure parameter and hoping it lines up.

Two rules when you do this:

- Do not also set a conflicting maximum exposure in the analysis parameters. The selection
  already pins the window, and a second constraint either empties cells or re-filters silently.
- Check the right edge is mature. List units at risk by build month across the selected rows.
  The count should track build volume. A sharp fall in the newest columns means those cells rest
  on whichever units happened to be built earliest in the month.

## Censoring, reporting lag, and Maximum Exposure vs. Maturity Level

Both right censoring and reporting lag make recent data look better than it is, and both bite
hardest exactly where an alert lives.

- **Right censoring.** A unit that has not yet reached the target age has not had its chance to
  fail. Coded as a non-failure in a decision tree or a rate denominator, it becomes evidence
  that recent builds are safe, which inverts the signal you are investigating. Restrict the
  population to units that reached the window, or shorten the window until they have.
- **Reporting lag (`Claim Submit Lag`).** Claims arrive weeks to months after the repair, so the
  most recent periods always under-report. In FQA's common analysis settings, specifying a
  non-zero `Claim Submit Lag` (e.g. 1 month) subtracts that lag from each unit's actual time in
  service (`Adjusted TIS = Actual TIS - Submit Lag`), reducing the population-at-risk denominator
  in recent intervals and shifting adjusted/extrapolated failure rates upward to compensate for
  claims not yet submitted. Check whether claim submit lag adjustment is enabled in the tenant's
  global defaults; for Event Forecasting, measure the typical repair-to-submission lag and hold
  that many periods back from the fitting window.
- **`Maximum Exposure` vs. `Maturity Level` (Event Filter vs. Unit Filter in Common Settings):**
  - **`Maximum Exposure`** caps the *event* time-in-service (or usage) interval included in the
    analysis. Events occurring at `TIS > Maximum Exposure` are excluded, **but no product units
    are removed from the sample size (denominator)**. Use `Maximum Exposure = 1` or `3` months on
    Trend & Control (with `Adjusted` calculation method) to monitor early-life infant mortality.
  - **`Maturity Level`** sets the minimum *product* time in service a unit must have reached at
    the refresh date to be included in the analysis. Units with `Product TIS < Maturity Level`
    **and all events on those immature units** are removed from both numerator and denominator.
    Setting **`Maturity Level = 0`** is the standard technique to exclude **unsold units** (units
    built but lacking an in-service date).
  - **`Minimum Sample Size Type` (`None`, `Count`, `Percent`) & `Minimum Sample Size`**: Excludes
    individual TIS bins whose unit count or percentage of the population at risk falls below the
    threshold, preventing noisy spikes in tail TIS bins where only a few old units remain.
- **`Claims Per Unit to Include` (`All`, `First Claim Per Type`, `First Claim Per Unit`) — the
  Data-Mart Defect Key Trap:**
  - `First Claim Per Type` is flagged **during the ETL data mart load** using the configured
    **Defect Key** (e.g., primary labor group or object code), *not* dynamically after Data
    Selection filtering.
  - **Trap:** If a vehicle had its first claim for Defect X in 2021 (outside your Data Selection's
    event date filter) and a second claim for Defect X in 2023 (inside your Data Selection),
    setting `Claims Per Unit to Include = First Claim Per Type` will **exclude the 2023 claim**
    because it is not the unit's first-ever mart claim for that Defect Key. Keep `All` when
    filtering event date windows unless you verify the unit's full claim history is in scope.

