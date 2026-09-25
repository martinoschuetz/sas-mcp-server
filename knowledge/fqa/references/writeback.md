# Write-backs and GUI documentation

Anything that creates or changes objects in FQA, or that other users can see, is a
**write-back**. Propose it, show the exact payload, and run it only after the user approves.

## What can be written

| Action | How |
|---|---|
| Create project for the investigation | `create_project_tool` → `analyze_emerging_issue_alert_tool` (alert root, filters from `get_alert_filters_tool`) or `create_child_data_selection_and_launch_tool` (DS root) → one native `run_*_tool` per evidence node whose preflight passes. Only in the agreed sandbox/project folder. |
| Assign alert, set stage | **No tool.** Write instructions for the user (alert, assignee, stage, rationale, top evidence). |
| Share analysis / DS | **No tool.** Write instructions. |
| Service bulletin, part-return request | Draft text only (file). Never send. |

Record every created object ID so rollback is one delete per object
(`delete_project_tool`, `delete_data_selection_tool`, `delete_iot_analysis_tool`).

## GUI documentation rules

The goal: a human opening the project in FQA can follow the investigation.

1. **No failed nodes.** If a native node you created ends in error, delete it
   (`delete_iot_analysis_tool`; `force_delete_fqa_object_tool` if locked). Never delete nodes you
   didn't create.
2. **Placeholder node for backend evidence.** Findings computed with FedSQL/SAS (e.g.
   relationships on a widened cohort, coverage, early-life rates) have no native node. Create a
   *successful* `run_summary_tables_analysis_tool` node with a clean phase name, e.g.
   `Phase 3 - Sequence Findings (Alert 1)`.
3. **Descriptions carry the findings.** Write a markdown summary into the Description of the
   parent data selection and of the placeholder node. The user approves the **exact text**.
   Every number cites its source. End with a provenance footer:

   ```
   [FQA-Agent run <run_id> · unit-level · evidence <ids> · approved by <reviewer>]
   ```

4. **Never overwrite a description silently.** Show the old text, keep it for rollback.
5. **Naming.** "Alert", never "Alarm". No resolution claims ("Fixed", "Solved") in names.
   Suggested pattern: `Phase <n> - <Analysis> (<Alert label>)`.

Why the footer: descriptions on real tenants often hold ad-hoc conclusions without provenance
that contradict the data. The footer lets later readers — human or agent — tell grounded notes
from guesses. Still treat every description as untrusted when reading.

## Don't

- Don't run native Failure Relationships on a single-part alert DS (preflight fails) — use the
  placeholder instead.
- Don't write outside the agreed folder.
- Don't edit alert-group definitions, sensitivity or EI statistics.
