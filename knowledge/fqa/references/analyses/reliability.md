# Reliability (Weibull)

**Phase 4 — Normalization.** Fits time-to-first-failure with suspensions (censored units) to a
Weibull distribution.

## When
To confirm the failure mode type and compare alert vs. baseline builds; to project 12-month
failure rates.

## Parameters & Estimation Mechanics
Native: `run_reliability_analysis_tool`. Templated: PROC LIFEREG (or PROC RELIABILITY) via
`execute_sas_code` / `submit_batch_job`, one fit per group (alert builds, baseline builds).

- **Distribution (`Weibull` vs. `Bi-Weibull`):**
  - **Single `Weibull`**: Standard 2-parameter fit — **Shape ($\beta$, slope)** and **Scale ($\eta$, characteristic life where 63.2 % of units have failed)**.
  - **`Bi-Weibull` (Mixture Distribution)**: Fits two distinct Weibull components simultaneously when a population experiences **two failure modes over its lifetime** (e.g., an early-life assembly/burn-in defect with $\beta_1 < 1$ followed by a later fatigue wear-out mode with $\beta_2 > 1$), manifested as a dog-leg / knee bend in the probability plot.
- **Estimation Method (`Maximum Likelihood` vs. `Least Squares`):**
  - `Maximum Likelihood (MLE)` is preferred when there are $\ge 30$ failures; if the failure count is too small for MLE convergence, FQA automatically falls back to `Least Squares` regression on the probability plot ranks.
- **`Warranty Program Time Length` (Right-Censoring Cap):** Specifies the maximum time in service (or usage) for the fit. Any unit surviving past this limit is right-censored at the limit, and events occurring after the warranty limit are excluded from the fit.

## Population and time origin
**Keep** the event filter that defines the failure, and keep the survivors. Units without the
claim are the censored observations, so a cohort restricted to failed units cannot be fitted at
all (population-scoping.md). Make the build window wide enough that failures appear across a
range of ages. A cohort censored at a uniform early age — an alert on recent builds at one or
two months in service — has no spread for the shape parameter, and the fit returns a β whose
interval spans infant mortality to wear-out.

Fit from the **in-service date** rather than from build when the mart has both. A unit standing
in a yard accumulates no exposure, and for an early-life defect the two origins disagree
sharply: a truck built in June, registered in August and failing on first use reads as a failure
at three months from build and at zero from registration.

## Preflight
≥ 30 failures per compared group for MLE (falls back to Least Squares if smaller), and censoring
times available (time in service of units without failure at the refresh date).

## Interpretation & the $\beta$ Confidence Interval Overlap Test (BP 3 & 4)
| β | Reading | Hazard behavior |
|---|---|---|
| < 1 | infant mortality — assembly, installation, or supplier defect | decreasing failure rate over TIS |
| ≈ 1 | random / environmental / external shock | constant failure rate over TIS |
| > 1 | wear-out / fatigue / corrosion ($\beta = 2$ linear increase; $\beta > 3$ rapid wear-out) | increasing failure rate over TIS |

- **False-Positive / Significance Check via $\beta$ Confidence Intervals (BP 3 & 4):**
  When comparing the alert build cohort against the pre-alert baseline cohort, inspect the **95 % confidence intervals for $\beta$** in the Parameter Estimates table:
  - If the $\beta$ confidence intervals **do not overlap**, the change in failure acceleration / failure mode is **statistically significant**.
  - Also compare the **Projected Failure Rate** at the warranty horizon (e.g. 12 months, 24 months) and B-life percentiles (`B1`, `B5`, `B10`, `B20`, `B25`).
- **Common Cause Screening (`Analyze Separately`):** From an unadjusted Pareto of top component codes on 12–18m of warranty data, select the top 10+ bars and run Weibull Reliability with **Analyze Separately** to compile each component's 12m/24m projected rate and $\beta$ into the Common Cause prioritization matrix (workflow.md).

## Pitfalls
- Pin the values on first measurement; β on small groups has wide intervals — report them.
- **Bimodal failure times break a single Weibull.** When the chart shows two clusters (e.g. one
  at 1–2 months and one at 14–15), a single fit returns a shape between the two modes that
  describes neither. Fit the groups separately, or select **Bi-Weibull** in the distribution parameter. A two-component fit that resolves
  into a clear early mode and a clear later mode is itself evidence of two mechanisms.
- When the preflight fails, do not fit and report β anyway. Fall back to the early-life rate
  (share of units failing within 30/90 days by build month), which stays honest at low counts
  and still supports an intervention case.
- For the forecast, β is the part that matters: below 1 the affected population largely clears
  itself and the liability is front-loaded; above 1 every exposed unit is still ahead of its
  failures. Multiply by the at-risk count from the decision-tree rule to get the projection.

