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

---

## 4. Production VA Hardening (Rule 11) & Rendering Performance (`[VERIFIED]`)

Live testing on `45,779` 5-minute intervals (`640k–778k` transposed sensor/SHAP rows) across `SVDD_ASSET`, `ISOLATION_FOREST`, `MTS_SIMPLE`, and `MTS` established five non-negotiable BIRD XML rules:

1. **Custom Graphs Ignore `autoInteractionMode="oneWayFilter"`:**
   SAS Visual Analytics `graphType="custom"` objects (SPC, threshold/severity, and Scatter+Series overlays) do not support automatic section actions (*"Automatic actions are not supported"*). Always:
   - Omit `autoInteractionMode="oneWayFilter"`.
   - Include `PAM_ASSET_ID` in both the slider's `MultidimensionalDataDefinition` (`applyDynamicBrushes="promptsOnly"`) and the graph's `ParentDataDefinition`.
   - Set `required="true"` + `<DefaultValue><String dynamicValue="first" behavior="dynamic"/></DefaultValue>` on `<Prompt>` (never put `required="true"` on `<NumericRangeConstraint>` per `bird-4.42.0.xsd`).
   - Wire explicit `<Interaction type="filter">` rules (`Asset -> Slider`, `Asset -> Graph`, `Slider -> Graph`).
2. **Always Reset `<SASReportState><View/></SASReportState>`:**
   Exporting a report from VA after interactive testing embeds saved `<PromptState>` asset codes (e.g., `'KaHA231D'`) and hardcoded epoch slider bounds inside `<SASReportState>`, locking future instances to stale assets or missing columns. Strip `<SASReportState>` down to `<SASReportState><View/></SASReportState>` (keeping intentional dynamic default parameter placeholders such as `{{.ANALYSISVAR1}}` in `MTS` only where required).
3. **Respect the 250,000-Cell `sas-report-data` Ceiling:**
   Leaving `maxRowsLookup="graphDefault"` / `"heatmap"` / `"scatter"` with `maxRowsBehavior="noData"` triggers silent `dataTruncatedToNothing` blank visuals on >5k–30k rows (`45,779 × 8 = 366k` cells!). Trim `MultidimensionalDataDefinition` columns to strictly plotted/tip columns (`<= 3` columns supports up to `83,333` timestamps/asset untruncated), set `maxRows="250000" maxRowsBehavior="truncate"`, and set `detail="false"` on long transposed sensor/TreeSHAP queries.
4. **Use Continuous `<SeriesPlot connectOrder="xaxis">` + `<TimeOpts>` Instead of Discrete `<LineChart>`:**
   A discrete `<LineChart>` (`<XAxisOpts type="discrete">`) treats `45,779` timestamps as `45,779` string categories and crashes `sas-report-images` with `HTTP 500` / `EOF`.
5. **Local Explainer Bar-to-Scatter Alignment (`ve364 -> ve310`):**
   Keep `<InternalDataSourceMapping>` (`ds_sha -> ds_trans`) and `sourceInteractionVariables` on `(vname -> _NAME_, PAM_ASSET_ID)` only — omit `DATETIME` (`bi343 -> bi8`) so clicking a SHAP bar shows the sensor's full trajectory while the `DATETIME` parameter prompt highlights the chosen timestamp.
6. **Avoid `14x` Table Fan-Out, Dead Queries & 45k-Point DOM Explosions:**
   - Do **not** drive 1-row-per-timestamp score charts, sliders, and asset prompts off a $p\times$ transposed sensor table (`640k` rows), and remove unused `<DataDefinition>` queries left over from deleted plots inside `synchronized` containers.
   - Avoid plotting `45,780` `<ScatterPlot>` `<circle>` elements or `display="ALL"` markers on dense curves (generates `~4.3 MB` / `92k`-line SVGs that stall browser rendering).
   - Never rely on raw `Alt+Ctrl+B` copy-paste without stripping `<SASReportState>` and checking both `<Weight>` counts (`mt3`, `mt4`, `mt5`) and `nextUniqueNameIndex`.
