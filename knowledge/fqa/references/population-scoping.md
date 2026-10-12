# Population scoping: which data for which analysis

The most common way to get a wrong answer in FQA is not a bad parameter. It is running the
right analysis on the wrong population. Each analysis needs a different slice, and the slice
that is correct for one is degenerate for the next. Decide three things separately for every
node.

## Contents
- The three axes
- Per-analysis scoping table
- Never condition on the outcome
- Analyses that need elapsed time
- Calendar time is not age
- Equalizing exposure with cell selection
- Censoring and reporting lag

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
| Text Mining | Widest scope that still holds the pattern | Keep, but check which domain holds the text | Any age |
| Failure Relationships | A comparable cohort **not** conditioned on having failed | **Remove.** You need the other claims | Long. Units need months of history |
| Reliability | All units of the cohort including survivors | **Keep.** It defines the failure event; survivors are the censoring | Long, with failures spread across ages |
| Event Forecasting | Fleet or product line | Keep | Calendar history, truncated short of the refresh date |

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

## Censoring and reporting lag

Both of these make recent data look better than it is, and both bite hardest exactly where an
alert lives.

- **Right censoring.** A unit that has not yet reached the target age has not had its chance to
  fail. Coded as a non-failure in a decision tree or a rate denominator, it becomes evidence
  that recent builds are safe, which inverts the signal you are investigating. Restrict the
  population to units that reached the window, or shorten the window until they have.
- **Reporting lag.** Claims arrive weeks to months after the repair, so the most recent periods
  always under-report. Check whether claim submit lag adjustment is enabled in the tenant's
  global defaults. When it is off, nothing compensates, and any model fitted through those
  periods reads the artificial decline as a trend. Measure the typical lag by comparing repair
  dates against submission dates, then hold that many periods back from any fitting window.
