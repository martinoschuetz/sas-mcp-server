# Geographic

**Phase 1 — Descriptive.** Maps claim rates by region (repair-dealer state, customer state,
selling-dealer country).

## When
- Suspected environmental or operational stressor (cold, heat, altitude, road salt).
- As a **negative control** once a production hypothesis exists: a production defect should not
  concentrate geographically (unless affected lots were shipped regionally).

## Parameters
Native: `run_geographic_analysis_tool`. Also part of `fqa_template_descriptive_triage_tool`.

Use a **rate**, never a claim count: a count map shows fleet size by market and looks identical
for any code you pick.

## Which geographic variable
| Variable | Lives on | Answers | Rate possible |
|---|---|---|---|
| Customer country | product | where the unit operates; closest proxy for climate, duty cycle, fuel | yes |
| Selling dealer country | product | where it was sold; reliably populated, and determines market specification | yes |
| Repair/workshop country | claim | where it was repaired; follows the real territory | **no** |

Pick a **product-level** variable. A claim-level one exists only for units that were repaired,
so units without a claim contribute nothing to the denominator and no rate can be formed. Use
the claim-level one as a secondary count view to test one thing: if the customer country is
domestic but repairs are spread across many markets, the fleet roams and geography is a weak
discriminator whatever variable you choose.

Country is usually the floor, because the geocoding reference is keyed on country codes. Values
with no coordinate entry are warned about during the load and then silently absent from the map,
so compare the mapped total against the subset total before trusting it.

## Evidence (templated)
Rate per region = units with the event ÷ units at risk in that region, with n. Only regions
with n ≥ 25. Apply multiplicity control (many regions → some look extreme by chance).

## Interpretation
- A wide range on small n (reference tenant: 14 %–42 % across states) is noise until a corrected
  test says otherwise.
- "No significant region" is a useful finding — report it; don't cite geography as a driver.
- Flat geography is the *supporting* outcome for a production hypothesis: a supplier or build
  change travels with the units wherever they go.

## Pitfalls
- **Delivery lag skews early-TIS cohorts toward near markets.** At zero to two months from
  build, a unit reaches a domestic customer in weeks and an export market in months, so distant
  markets look falsely clean. If a concentration appears in the home region, re-run with time in
  service measured from registration instead of from build. If it disappears, it was delivery
  lag and not a regional effect.
- **Geography can be production in disguise.** Markets served by a local assembly site, or
  knocked-down series assembled in-market, entangle "where it runs" with "where it was built".
  Check whether plant and assembly line are significant drivers before reading a map as
  environmental, and split in-market-assembled series from home-plant series first.
- **Market specification follows geography.** Emission and homologation variants differ by
  market, so a country effect may be a specification effect. Hold the specification constant and
  see whether the country difference survives.
