# Summary Tables

**Phase 1 — Descriptive.** Cross-tabulates top failing codes against product attributes.

## When
- The Pareto is flat or ambiguous: look at top codes × build month, × model (× engine family,
  plant, … if the mart has them) to spot categorical skews.
- As the **placeholder node** in the UI for findings computed outside FQA (writeback.md).

## Parameters
Native: `run_summary_tables_analysis_tool` with `report_var`, `analysis_var`, `data_domain`,
`folder_id`, `parent_analysis_id`.

## Evidence (templated)
Counts of claims and distinct units per (code × attribute level), plus unit denominators per
attribute level so you can compare rates, not raw counts.

## Preflight
≤ 50 levels per dimension; aggregate to groups otherwise.

## Interpretation
A code concentrated in a few build months points to production; spread across all months and
attributes points to usage or a field-side cause.
