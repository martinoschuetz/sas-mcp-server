# CAF UI Controls, Dynamic Lookups & SpEL `<Interactions>`

Deep-dive reference on how the SAS Analytics for IoT React UI (`app.js` & `4983.bundle.js`) and mid-tier (`sas-iot-analysis` / `sas-iot-analysis-models`) evaluate `<LookupMetadata>` and SpEL `<Interactions>`.

---

## 1. Control-by-Control `RESOLVEONUI` Matrix (`[VERIFIED]`)

Every parameter lookup in `spec.json` (`<LookupMetadata>` in `input.xml`) uses one of four modes:
- **Static (`lookup` omitted or `type: null` with `possible_values`):** Fixed `<PossibleValues><Values key="..." value="..."/></PossibleValues>`.
- **Shared Platform Lookup (`type: null`, `is_reused: true`, `shared_reference: true`):** References a built-in AIoT lookup by ID (`PERIODICITY_UNIT`, `AGGREGATION_METHOD`, `QUERY_ONLY_CAS`, `TARGET_TRANSFORM`, etc.).
- **Inline `RESTAPI` (`type: "RESTAPI"`):** Queries an internal Viya REST endpoint (e.g., `/casManagement/servers/cas-shared-default/caslibs?limit=100000&dest=123`).
- **Inline `CASTABLE` (`type: "CASTABLE"`):** Queries a promoted CAS table (`LibraryName`, `TableName`, `KeyColumnName`, `ValueColumnName`, `WhereCondition`).

### Which Controls Must Set `RESOLVEONUI=true`?

| `displayControl` | Lookup `properties` | What `POST .../inputs/{param}/possibleValues` Returns | Why (`app.js` Behavior) |
| :--- | :--- | :--- | :--- |
| **`STABLEPERIOD`** | `{"RESOLVEONUI": "true"}` (**REQUIRED**) | 6 metadata rows (`RESOLVEONUI`, `LibraryName`, `TableName`, `KeyColumnName`, `ValueColumnName`, `WhereCondition`) | `4983.bundle.js` reads those 6 metadata items to call `POST /casRowSets/.../rowSets` directly for the interactive time-series plot, and `app.js` skips `currentValues` key-filtering on `STABLEPERIOD`. |
| **`MULTIINPCHKTABLE`** | `{"RESOLVEONUI": "true"}` (when client-queried) | Metadata rows for multi-column table widget | Explicitly exempted from `currentValues` key-filtering in `app.js`. |
| **`SINGLESELECT`** | `{}` (**MUST OMIT `RESOLVEONUI`**) | Server-queried data rows (`[{"key": "IDCP_CH18B", "value": "Chiller 18B"}, ...]`) | `app.js` (`yi` widget + `fetchPossibleValues`) renders `possibleValues` as table rows and **intersects `currentValues` with `possibleValues` keys**! Setting `RESOLVEONUI=true` wipes saved selections to `[]` on step open! |
| **`MULTISELECT`** | `{}` (**MUST OMIT `RESOLVEONUI`**) | Server-queried data rows (`[{"key": "CHWET_DEGC", "value": "CHWET_DEGC"}, ...]`) | `app.js` (`ui` widget + `fetchPossibleValues`) renders `possibleValues` as multi-select rows and **intersects `currentValues` with `possibleValues` keys**! Setting `RESOLVEONUI=true` wipes all saved multi-select items on step open! |
| **`DROPDOWN`** | `{}` (**MUST OMIT `RESOLVEONUI`**) | Server-queried data rows (`[{"key": "QASAnlOut", "value": "QASAnlOut"}, ...]`) | Renders `possibleValues` items verbatim as `<Select>` options and filters `currentValues` against `possibleValues`. Setting `RESOLVEONUI=true` displays literal `"RESOLVEONUI"`, `"LibraryName"`, `"TableName"` in the dropdown! |

### Verified `spec.json` Examples

#### `SINGLESELECT` / `MULTISELECT` Cascading `CASTABLE` Lookup (`properties: {}`)
```json
{
  "name": "INPUTVARS",
  "display_text": "Input Variables",
  "required": false,
  "visible": true,
  "order": 1,
  "data_type": "Array",
  "display_control": "MULTISELECT",
  "properties": {
    "table_columns_headers": "Variable",
    "table_columns": "key",
    "show_key": "false"
  },
  "lookup": {
    "id": "IF_INPUTVARS_LKP",
    "name": "IF_INPUTVARS_LKP",
    "is_reused": false,
    "type": "CASTABLE",
    "properties": {},
    "cas_table": {
      "library": "QASANLOUT",
      "table": "{{getCurrentValue $.values \"TARGET_VAR_TABLE\"}}",
      "key_column": "{{getCurrentValue $.values \"TARGET_VAR_COLUMN_NAME\"}}",
      "value_column": "{{getCurrentValue $.values \"TARGET_VAR_COLUMN_NAME\"}}",
      "where": "{{getCurrentValue $.values \"ASSET_VAR_KEY_COLUMN\"}}='{{getCurrentValue $.values \"SM_ASSET_VARIABLE\"}}'"
    }
  }
}
```

#### `STABLEPERIOD` Lookup (`properties: {"RESOLVEONUI": "true"}`)
```json
{
  "name": "STABLE_PERIOD",
  "display_text": "Stable periods",
  "required": false,
  "visible": true,
  "order": 3,
  "data_type": "String",
  "display_control": "STABLEPERIOD",
  "properties": {
    "SKIP_VALIDATION": "true"
  },
  "lookup": {
    "id": "IF_STABLE_PERIOD_LKP",
    "name": "IF_STABLE_PERIOD_LKP",
    "is_reused": false,
    "type": "CASTABLE",
    "properties": {
      "RESOLVEONUI": "true"
    },
    "cas_table": {
      "library": "QASANLOUT",
      "table": "{{getCurrentValue $.values \"TRANSPOSE_TABLE\"}}",
      "key_column": "DATETIME",
      "value_column": "{{getCurrentValue $.values \"TARGETVAR\"}}",
      "where": "{{getCurrentValue $.values \"ASSET_VAR_KEY_COLUMN\"}}=\"{{getCurrentValue $.values \"SM_ASSET_VARIABLE\"}}\""
    }
  }
}
```
> **Note on Quotes in `STABLEPERIOD` `where`:** Because `/casRowSets` passes `WhereCondition` into a CAS `table.fetch` / `where` clause, wrapping string values in double quotes (`PAM_ASSET_ID="IDCP_CH18B"`) or single quotes both work, while matching `SVDD_ASSET`'s `\"{{getCurrentValue ...}}\"` is live-verified on `4983.bundle.js`.

---

## 2. Canonical SpEL `<Interactions>` Patterns (`[VERIFIED]`)

### Pattern A: Data Selection vs. Existing CAS Table Toggle (Step 1)
```json
{
  "name": "DATASOURCE 01",
  "source_param": "DATASOURCE",
  "model_name": "ISOLATION_FOREST",
  "combinator": "AND",
  "order": 0,
  "condition": "#ctx.currentValue('DATASOURCE')=='SASTABLE'\n",
  "actions": [
    {
      "order": 0,
      "expression": "#ctx.show('SEL_SASTABLE')\n#ctx.show('SEL_CASLIB')\n#ctx.hide('PERIODICITY')\n#ctx.hide('PERIODICITY_UNIT')\n#ctx.hide('AGGREGATION_METHOD')\n#ctx.show('NOTAPPLICABLE')\n#ctx.disable('NOTAPPLICABLE')",
      "condition_result": true
    },
    {
      "order": 0,
      "expression": "#ctx.hide('SEL_CASLIB')\n#ctx.hide('SEL_SASTABLE')\n#ctx.show('PERIODICITY')\n#ctx.show('PERIODICITY_UNIT')\n#ctx.show('AGGREGATION_METHOD')\n#ctx.hide('NOTAPPLICABLE')",
      "condition_result": false
    }
  ]
}
```

### Pattern B: Caslib → CAS Table Cascade (Empty `<Condition>`!)
```json
{
  "name": "SEL_CASLIB 01",
  "source_param": "SEL_CASLIB",
  "model_name": "ISOLATION_FOREST",
  "combinator": "AND",
  "order": 0,
  "condition": "",
  "actions": [
    {
      "order": 0,
      "expression": "#ctx.fetchPossibleValues('SEL_SASTABLE')",
      "condition_result": true
    }
  ]
}
```

### Pattern C: Step 2 Asset → Tags → `STABLE_PERIOD` Cascade (Empty `<Condition>` + Self-Fetch Guard)
```json
[
  {
    "name": "SM_ASSET_VARIABLE 01",
    "source_param": "SM_ASSET_VARIABLE",
    "model_name": "ISOLATION_FOREST",
    "combinator": "AND",
    "order": 0,
    "condition": "",
    "actions": [
      {
        "order": 0,
        "expression": "#ctx.getChangedParamName() != 'SM_ASSET_VARIABLE' ? #ctx.fetchPossibleValues('SM_ASSET_VARIABLE') : #ctx.getChangedParamName()\n#ctx.fetchPossibleValues('INPUTVARS')\n#ctx.fetchPossibleValues('TARGETVAR')",
        "condition_result": true
      }
    ]
  },
  {
    "name": "TARGETVAR 01",
    "source_param": "TARGETVAR",
    "model_name": "ISOLATION_FOREST",
    "combinator": "AND",
    "order": 0,
    "condition": "",
    "actions": [
      {
        "order": 0,
        "expression": "#ctx.fetchPossibleValues('STABLE_PERIOD')",
        "condition_result": true
      }
    ]
  }
]
```

### Pattern D: Step 3 Scored Asset → Display Tag → `SCORE_PERIOD` Cascade
```json
[
  {
    "name": "SCORE_ASSET_VARIABLE 01",
    "source_param": "SCORE_ASSET_VARIABLE",
    "model_name": "ISOLATION_FOREST",
    "combinator": "AND",
    "order": 0,
    "condition": "",
    "actions": [
      {
        "order": 0,
        "expression": "#ctx.getChangedParamName() != 'SCORE_ASSET_VARIABLE' ? #ctx.fetchPossibleValues('SCORE_ASSET_VARIABLE') : #ctx.getChangedParamName()\n#ctx.fetchPossibleValues('SCORE_TARGET_VARIABLE', true)",
        "condition_result": true
      }
    ]
  },
  {
    "name": "SCORE_TARGET_VARIABLE_01",
    "source_param": "SCORE_TARGET_VARIABLE",
    "model_name": "ISOLATION_FOREST",
    "combinator": "AND",
    "order": 0,
    "condition": "",
    "actions": [
      {
        "order": 0,
        "expression": "#ctx.fetchPossibleValues('SCORE_PERIOD')",
        "condition_result": true
      }
    ]
  }
]
```

---

## 3. Simulating Browser UI Retention via REST (`[VERIFIED]`)

Before marking a multi-step CAF complete, verify parameter retention programmatically using the exact same endpoint as `app.js`:
1. `GET /iotAnalysis/analyses/{analysisId}` (`Accept: application/vnd.sas.iot.analysis+json`) → merge all steps' `inputParameters` and `outputParameters` into `vmap = {name: value}`.
2. `GET /iotAnalysis/analyses/{analysisId}` (`Accept: application/vnd.sas.iot.analysis.ui+xml`) → read `<CurrentValues><Values key="..."/></CurrentValues>` for each parameter on the target step (`ISOLATION_FOREST_2`, `ISOLATION_FOREST_3`).
3. `POST /iotAnalysis/analyses/{analysisId}/steps/{modelStepId}/inputs/{paramName}/possibleValues` with JSON body `{"values": vmap}`:
   - For `SINGLESELECT`, `MULTISELECT`, and `DROPDOWN`: confirm every saved `CurrentValues` key is present in `{item["key"] for item in resp.json()["items"]}` (`100%` retention).
   - For `STABLEPERIOD`: confirm `resp.json()["items"]` returns the 6 resolved metadata keys (`RESOLVEONUI=true`, non-empty `TableName`, `ValueColumnName`, `WhereCondition`).
