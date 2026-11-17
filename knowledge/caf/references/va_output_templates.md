# Visual Analytics BIRD XML Output Templates (`_vaoutput.template`)

Rules and workflow for authoring, tokenizing, and debugging CAF Visual Analytics report templates (`output/<STEP_ID>_vaoutput.template`).

---

## 1. Template Naming & Resolution Pipeline (`[VERIFIED]`)

1. **Filename Derivation:** For `<Step id="ISOLATION_FOREST_2" ...>`, the archive entry inside `<MODEL_NAME>.zip` must be `<MODEL_NAME>/ISOLATION_FOREST_2_vaoutput.template` (`caf_helpers.template_filename()` strips any trailing `_DEFAULT` and appends `_vaoutput.template`).
2. **Go `text/template` Rendering:** When a user opens a completed step's **Results** tab, AIoT loads `<STEP_ID>_vaoutput.template` and evaluates Go `text/template` slots (`{{.TOKEN}}`) against a dictionary containing:
   - All `analysisStepOutputParams` published by the current step and prior steps in the instance (`POST .../outputParams` or `%afi_caf_postprocess`).
   - All `inputParameters` of the step.
   - Ambient framework tokens (`{{.CASSERVERNAME}}`, `{{.LOCALE}}`, `{{.REPORT_THEME}}`, `{{.REPORTVAR}}`, `{{.__ANALYSISNAME__}}`, `{{.USERTITLE}}`, `{{.USERSUBTITLE}}`, `{{.USERFOOTNOTE}}`).
3. **Silent Failure on Missing Producer:** If `{{.MY_TABLE}}` has no matching key in that dictionary, Go `text/template` renders an empty string (`table=""`), and SAS Visual Analytics displays an empty container ("Data is not available") with **zero HTTP or SAS error**. Always check `caf_helpers.template_tokens()` / `validate_analysis_type_spec`!

---

## 2. Recommended Authoring Workflow (`templatize_va_report`) (`[VERIFIED]`)

**Never write BIRD XML from scratch.** Follow one of two proven paths:

### Path A: Prototype Live in VA + `templatize_va_report` (New Report Layouts)
1. Execute the step's SAS compute logic via `execute_sas_code` so real promoted tables exist in `QASAnlOut` (e.g., `QASAnlOut.DEMO_SUMMARY_A1B2C3D4`).
2. Create and style the Visual Analytics report using Tier 3 MCP tools (`create_report` + `apply_report_operations`) or in SAS Visual Analytics UI.
3. Convert the live report into a tokenized CAF template:
   ```python
   templatize_va_report(
       report_id="<va-report-uuid>",
       table_tokens={"DEMO_SUMMARY_A1B2C3D4": "SUMMARY"},
   )
   ```
4. Save the returned `template` string to `output/<STEP_ID>_vaoutput.template`.

### Path B: Adapt a Verified Reference Template (Matched Multi-Tab Layouts)
When building an analysis type whose Output Layer intentionally mirrors a working model (e.g., `ISOLATION_FOREST` mirroring `SVDD_ASSET`'s 3-tab `SPC Score` + `Global Explainer` + `Local Explainer` layout):
1. Export the reference template via `export_analysis_type("SVDD_ASSET", include_templates=True, step_id="SVDD_ASSET_2")`.
2. Ensure every `<DataItem xref="..."/>` column name, format, and filter expression in the template matches the exact columns produced by your SAS step:
   - Check **both** `DataSource/@label` and `CasResource/@table` (`{{.TS_TRANS_TABLE}}`, `{{.GIMPORTANCE_TABLE}}`, `{{.TS_SHA_T_TABLE}}`).
   - Check column `xref` case sensitivity (`_Anomaly_`, `P__Anomaly_`, `THRESH_IF`, `vname`, `shapely`, `ashapely`, `_LCLI_`, `_MEAN_`, `_UCLI_`, `_TESTS_`).
   - When using `PROC ASTORE` `setoption TREESHAP 1;` on target `<TargetVar>`, SAS creates columns `S_<TargetVar>_<InputVar>` and `S_<TargetVar>__INTERCEPT_`. Compute the exact prefix length (`length("S_<TargetVar>_") + 1`; e.g., `12` for `S__Anomaly_`) so `vname = substr(_name_, 12)` produces exact input tag names and `_INTERCEPT_` matches the Local Explainer filter `notIn(${bi...,binned}, '_INTERCEPT_')`!

---

## 3. Dual-Attribute DataSource Invariant (`[VERIFIED]`)

Every relational CAS table in BIRD XML **must** carry `{{.TOKEN}}` in **two** places:

```xml
<DataSource label="{{.TS_TRANS_SCO_TABLE}}" type="relational" name="ds99">
  <CasResource server="{{.CASSERVERNAME}}" library="QASANLOUT" table="{{.TS_TRANS_SCO_TABLE}}" locale="{{.LOCALE}}"/>
  <BusinessItemFolder>
    ...
  </BusinessItemFolder>
</DataSource>
```

If `DataSource/@label` retains a hardcoded table name from a prototype run (`label="SVDD_TS_T_SCO_E0DCBD01"`) while `CasResource/@table` is tokenized (`table="{{.TS_TRANS_SCO_TABLE}}"`), Visual Analytics fails to bind the data source on new instances.
