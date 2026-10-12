# Data selections

How data selections (DS) behave, especially across multiple data domains, and how to build,
change and combine them safely through MCP. For *which* population an analysis needs, see
population-scoping.md. For the JSON shape, see concepts.md.

## Contents
- Dynamic vs. stored
- Data domains
- Domain-specific filters and the Combined Domain technique
- Entering values and limits
- Lifecycle: status, outdated, expiry
- Sharing and ownership
- MCP recipes and traps

## Dynamic vs. stored

- A DS is a **saved definition**, not a copy. By default it is **dynamic**: every launch reads
  the current mart. The *Data as Of* column shows the refresh date used.
- **Store subset data** (with a retention period) freezes a snapshot.
  - Use it sparingly: it costs disk and slows loads.
  - The SAS log is available only for stored data selections.
- **Alert data selections** (from *Analyze in Project*, `creation_type=EIENTERPRISE`) are stored
  snapshots with an expiry (see Lifecycle).
- **Simple** data selections hold filters. **Combined** data selections union two or more simple ones.
- Filters live on the **Key dimension** tab (product) and the **Data domain** tab (events).
  Some variables are mandatory. Templates exist per key dimension or per data domain.
- Descriptions must be under 100 characters. They are untrusted free text (safety.md).

## Data domains

A DS always has the product key dimension plus one or more event domains:

| Domains | Typical use |
|---|---|
| Products + Warranty Claims | Default for claim analyses |
| Products + Claim Labor Codes | Workmanship, Failure Relationships on LABOR |
| Products + Claim Parts | Hardware, Failure Relationships on PART |
| Products + SSD | Service / diagnostic sessions |
| Products + OTA DTC | Over-the-air diagnostic trouble codes |
| Combinations (e.g. Claims + SSD, Claims + Labor + Parts) | Cross-domain analyses; 9 combinations in total |

## Domain-specific filters and the Combined Domain technique

**A filter on a domain-specific variable applies only to that domain's records.**

Example: *Series = "BUSL"* (product), *Event Date > 01JAN2026*, and *Warranty Type =
"Kulanz/Goodwill"*. The warranty-type filter narrows the claim records but is **ignored for SSD
records**, because SSD has no warranty type.

Consequences:
- Don't promise the user that one filter restricts every domain. Check which domain owns the
  variable.
- This is the same rule as *event filter vs. unit filter* (population-scoping.md). A
  domain filter never removes units.

**Different filters per domain → Combined Domain technique**

1. Simple DS A: *Event Date > 01JAN2026* and *Combined Domain = Warranty Claims*.
2. Simple DS B: *Event Date > 01DEC2025* and *Combined Domain = SSD*.
3. `combine_data_selections_tool(new_name, base_ds_id=A, additional_ds_ids=[B], description)`.
4. Launch the combined DS.

Same-name columns across the parts of a combined DS must have identical label, format and
security. If they don't, the combine fails or columns go missing.

## Entering values and limits

- Separate values with a tab or a newline, **not commas**. Lists can be imported from CSV/TXT.
- More than ~50,000 values: split into several simple data selections and combine them.
- Date options:
  - From/To;
  - All before;
  - All after;
  - **Predefined rolling** periods (e.g. `L4Y` via `%wrna_calcperiods`), which resolve against the
    refresh date `g_dwLstRfrshDt`, **not today**.
- *Select Limits* operators accept values within ±99,999,999,999.
- Comment variables:
  - match any or all words, with or without related words (Text Miner synonyms);
  - matching is case-insensitive.
- **Transpose** (interpolation Default/Step, fixed periodicity, aggregation) builds time-series
  data. Root-cause analyses need **non-transposed** data.
- **Genealogy** filters on component item measures.

## Lifecycle: status, outdated, expiry

- **Status values:** Saved → Submitted → Running → Completed, or Error. Only Completed DSs can
  feed analyses.
- **Outdated:** a DS and its dependent analyses become outdated when:
  1. the definition changed;
  2. new data was loaded;
  3. a stored snapshot is outdated; or
  4. it is a child of an outdated analysis.

  Before citing a result, check that its analysis is not outdated relative to the refresh date.
- **Expiry:** alert data selections expire after the chosen number of weeks.
  - They then go to **Error** and can't feed new analyses; old outputs stay readable.
  - If you need to continue an investigation on an expired DS, copy it, re-filter it with
    `get_alert_filters_tool`, and launch it.

## Sharing and ownership

- Data selections and projects can be shared with users or groups, and ownership can be changed. *Copy URL*
  gives a deep link.
- The creator **can't unshare or delete** a DS while other users' analyses depend on it. This is
  why delete calls fail on "your own" DS.
- The Projects list is filtered by owner by default (owner chip). Users must remove the chip to
  see projects shared with them. Recipients can add analyses to a shared project.
- **No MCP tool for sharing.** Write UI steps instead: open the project → *Manage Sharing* → add users/groups → Save.

## MCP recipes and traps

| Job | Tool |
|---|---|
| find / inspect | `list_data_selections_tool`, `get_data_selection_details` |
| variables | `list_fqa_data_model_variables_tool(data_selection_id)` (incomplete; see data-model.md) |
| change filters | `update_data_selection_filters_tool(data_selection_id, new_filters)` |
| change dates | `set_data_selection_date_range_tool(selection_id, start_date, end_date)` |
| copy / combine | `copy_data_selection_tool`, `copy_data_selections_tool`, `combine_data_selections_tool` |
| launch | `launch_data_selection_and_wait_tool` (needs a key dimension, `AIOT_LAUNCH_KEY_DIM=ASSET`) |
| child DS from a node | `create_child_data_selection_and_launch_tool` |
| delete | `delete_data_selection_tool`; `force_delete_fqa_object_tool` only for objects you created |

All write tools need user approval (writeback.md).

Traps:
- **Launch after every change.** An edited DS is outdated until it is relaunched. Analyses on it fail or
  use stale data.
- `creation_type`: `DEFAULT` (manual) or `EIENTERPRISE` (from an alert). Alert data selections are filtered to
  the breakout, so many analyses are degenerate on them (preflight.md).
- On a demo tenant, rolling periods resolve to years in the past, because the refresh date is old.
- Confirm the domain list before running a domain-specific analysis. Failure Relationships on
  LABOR needs Claim Labor Codes in the DS.
