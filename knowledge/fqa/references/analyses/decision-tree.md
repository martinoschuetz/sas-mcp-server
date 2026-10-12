# Decision Tree

**Phase 2 — Segmentation.** The primary tool for generating explicit filter rules for a
high-risk sub-population (recall narrowing: "from 1,000,000 units to 10,000").

## When
- You need to describe *which units* are affected, as a Boolean rule.
- To test a secondary modifier within an affected stratum.

## Parameters
Native: `run_decision_tree_analysis_tool`. Templated: HPSPLIT / tree procedure with fixed seed.
Target: event or rate (e.g. seq90, early-life failure). Candidates: build month, model, dealer
state, event status, TIS bin, text cluster IDs. Min leaf = max(1 % of units, 100).

Keep the tree **shallow** (3–4 levels). The deliverable is a rule a person applies to a vehicle
list, not a model. Check that any leaf you intend to act on holds enough *claims* (10–20), not
just enough units.

## Target: the censoring trap
Use a binary unit-level target ("had the claim within its first N months in service"), then
**restrict the population to units that actually reached N months** at the refresh date.

Skip that restriction and the tree inverts your signal. Immature units have not had the chance
to fail, enter the model coded as non-failures, and teach the tree that the newest builds are
safe — the exact opposite of the alert you are investigating. If you need the newest builds in,
shorten N until they qualify. Where claim submit lag adjustment is disabled on the tenant, the
newest builds already under-report before any censoring error is added on top.

## Run it twice
1. **With one time variable.** It will split on build period near the root, which gives you the
   stratification for free, and the splits beneath show what separates failing units inside the
   change window. Include only *one* time field: build month, engine build month, delivery month
   and registration month are collinear and will waste depth.
2. **With no time variable at all.** Force the tree to explain the failure from specification
   alone. This is what produces the usable deliverable, because "built after June 2026" cannot be
   checked against a vehicle record while an engine type plus emission limit plus type number can.
   If specification alone cannot produce a high-rate leaf, the cause is not in the configuration
   data and you are looking at a batch or supplier effect inside one configuration.

Then test the leaf: **did that configuration exist before the alert window?** If those units
were already in production and not failing, the configuration is not the cause and something
changed within it — go to the as-built bill of materials. If the configuration first appears in
the alert window, the change itself is the carrier and the rule is sound.

## Preflight
≥ 100 events and ≥ 2 × min leaf; all candidates in the mart dictionary. On a single code at low
service ages you may not reach this even across a long build window; if you fall short, compare
as-built part numbers between affected and clean units instead.

## Evidence
Per node: definition (path from root), units, claims, rate; variable importance.

## Interpretation
- Focus on terminal leaves with rates far above the fleet average; trace the path back to the
  root to get the combined filter.
- Save the rule as a data selection so it can be reused across nodes (write-back, approval).
- Feed text cluster IDs in as candidates to combine build attributes with symptoms.

## Pitfalls
A node path from the demo ("labor group chassis") may not exist on another tenant; build rules
only from variables in the dictionary.
