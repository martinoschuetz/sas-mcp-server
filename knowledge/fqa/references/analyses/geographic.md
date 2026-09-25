# Geographic

**Phase 1 — Descriptive.** Maps claim rates by region (repair-dealer state, customer state,
selling-dealer country).

## When
- Suspected environmental or operational stressor (cold, heat, altitude, road salt).
- As a **negative control** once a production hypothesis exists: a production defect should not
  concentrate geographically (unless affected lots were shipped regionally).

## Parameters
Native: `run_geographic_analysis_tool`. Also part of `fqa_template_descriptive_triage_tool`.

## Evidence (templated)
Rate per region = units with the event ÷ units at risk in that region, with n. Only regions
with n ≥ 25. Apply multiplicity control (many regions → some look extreme by chance).

## Interpretation
- A wide range on small n (reference tenant: 14 %–42 % across states) is noise until a corrected
  test says otherwise.
- "No significant region" is a useful finding — report it; don't cite geography as a driver.
