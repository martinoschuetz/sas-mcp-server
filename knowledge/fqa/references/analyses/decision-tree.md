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

## Preflight
≥ 100 events and ≥ 2 × min leaf; all candidates in the mart dictionary.

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
