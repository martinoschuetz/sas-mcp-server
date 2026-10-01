# FQA configuration files

The CSVs in `configuration/` are the single source of truth for what the FQA UI offers: which
tables and columns exist, which analyses see which variables, which defaults apply, how things
are labelled. They are read by `%afi_dataload` when `config=Y` (data-load.md). Most of them are
**generated** from the Data Elements Workbook (DEW) by the precode program; edit the DEW, not
the CSV, unless the file is listed as hand-maintained.

## Contents
- Origin: the DEW and precode
- table_parameters.csv
- column_parameters.csv
- global_defaults.csv
- analysis_param.csv and param_lookup.csv
- analysis_var.csv
- labels.csv
- fr_failure_relationships.csv and fr_trivial_rules.csv
- toc_report_var.csv
- geo.csv
- Hand-maintained vs generated

## Origin: the DEW and precode

The DEW is an Excel workbook (`FQA on Viya Data Elements Workbook - <customer> - <date>.xlsm`)
with a `Tables` and a `Variables` sheet. A VBA macro exports them to `fqa_dew_tables.csv`
(one row per staging table: `CUSTSTG_TABLENAME`, `CUSTSTG_PRIMARYKEY`, `CUSTSTG_FOREIGNKEY`,
`CUSTSTG_PRODUCTKEY`, `TABLEID`, `TARGET_TABLE_NM`, `TABLE_TYPE_CD`, ...) and
`fqa_dew_variables.csv` (one row per column: `TABLEID`, `NAME`, `LABEL`, `TYPE`, `LENGTH`,
`FORMAT`, `FILTERVARIABLEYN`, `LOOKUPTABLEYN`, `LOOKUPTABLENAME`, `ANALYSISVAR*`,
`DATEINTERVAL`, `TREEGROUP*`, `SCOPE`, `TARGET_COLUMN_NM`, validation rules, ...).

`TABLEID` encodes the data model: `1_P_P1` = product, `1_E_C1` ... `1_E_C5` = event types
(warranty claims, service desk, OTA DTC, NASYS DTC, workshop orders), with child suffixes such as
`_CP` (parts), `_LC` (labor), `_CM` (comments), `_PB` (BOM), `_FU` (FUPs), `_EC` (ECU).

`fqaetl_dataload_precode.sas` turns the two DEW files into the engine CSVs below. The DEW files
are also read at load time by the validation programs and by the DEW-enforcement utilities
(`%util_rem_stg_extravars`, `%util_set_length_stg_vars`).

## table_parameters.csv

One row per mart table (about 100 on the reference tenant).

| Column | Values / meaning |
|---|---|
| `table_name` | mart table (lookup codes are at most 14 chars, e.g. `C1_PRIM_CLMPRT`) |
| `table_func` | `DIM` or `FACT` |
| `table_type` | `COMMON` (only PRODUCT), `GENERAL` (lookups and most dims), `NONE` (facts) |
| `child_table` / `child_parent_table` | `Y` + parent for line tables: `CLAIMSLABOR`, `CLAIMSPARTS` under `CLAIMS`; `WOLABOR`, `WOPARTS` under `WO`; `BOM`, `ECU`, `FUPS` under `PRODUCT` |
| `primarykey`, `foreignkey`, `keycolumn_id` | e.g. `EVENT_ID` for every event fact, `CL_PARTS_ID`, `WO_LABOR_CODES_ID` |
| `load_order_facts` | 1 lookups, 2 PRODUCT, 3 event facts, 4 children |
| `table_label` | UI label |

## column_parameters.csv

One row per mart column (about 500). Key columns:

| Column | Meaning |
|---|---|
| `column_sub_type` | comma list of roles: `CATEGORICAL`, `DETAIL`, `EIANALYTIC`, `EIENTERPRISE` (usable as EI breakout), `ANALYSIS` (measure), `FORECASTING`, `FAILREL` (Failure Relationships target), `GEOGRAPHIC`, `COMMENT`, `EVENTDATE`, `EVENTDATE_PERIOD`, `PRODDATE`, `INSERVICEDATE`, `CURRENCY`, `PRIMARYCOST`, `INTEGER`, `DECIMAL` |
| `column_rest` | visibility: `0` mart + analytics + data-selection tree (DEW `FILTERVARIABLEYN=Yes`), `1` mart + analytics, not in the DS tree (`SCOPE` Computed / Data Mart), `2` mart only, `3` staging only, ignored (`SCOPE=Staging Area`) |
| `mart_column_name` | target name (from DEW `TARGET_COLUMN_NM`) |
| `descriptiontablename` | lookup providing the `_DESC` column |
| `format_name` / `informat_name` | e.g. `$4.`; a mismatch with the existing CAS table is logged by the dim-build override as a "new attributes" issue |

Practical consequences for analysts: a variable the native tools accept must have `column_rest`
0 or 1; EI breakouts need `EIENTERPRISE`; Failure Relationships only mines `FAILREL` columns.

## global_defaults.csv

`param_cd, group_cd, param_type_cd, default_value_txt`, loaded to `ANALYSIS_GLOBAL_DEFAULTS`.
This is where the ETL learns the names of the key columns and how to compute TIS.

| Group | Important keys (reference values) |
|---|---|
| GENERAL | `PRODDATE=PRODUCTION_DATE`, `CLAIMDATE=EVENT_DATE`, `PRODUCTS_PRODKEYVAR` / `CLAIMS_PRODKEYVAR=PRODUCT_ID`, `FAILURENO=FAILURE_NO`, `FIRSTFAIL=FIRST_FAILURE_FLG`, `BYVARFIRSTCLAIM=DAMAGE_CODE`, `MATURITYCRITERIAFROMBUILD/FROMSALE/USAGE=75`, `MINSAMPLESIZERULE=CURRENT`, `VALUELIMIT=100`, `DEFAULTLANGUAGE=english`, `SEQVAR=EVENT_DATE` |
| TIS | `TIS=TIMEINSERVICE`, `TISCALCTYPE=INTERVAL`, `TISINTERVAL=MONTH`, `TISFIXEDWIDTH=30.4166667`, `INSERVICEDATEVAR=REGISTRATION_DATE`, `USEINSERVICEDATE=TRUE`, bin column names `PRODUCT_TIS_BIN[_BUILD/_SALE/_SHIP]`, `EVENT_TIS_BIN[_BUILD/_SALE/_SHIP]`, `CREATEBINVALUEMETHOD=DYNAMIC` |
| CALCMETHOD | `ADJUSTEDAVAILABLE=TRUE`, `EXTRAPOLATEDAVAILABLE=TRUE`, `EXTRAPOLATEDRULE=CUMULATIVE`, `EXTRAPOLATEDSUMMARYMETHOD=WEIGHTED`, `MINTISCOUNT=3`, `ANNUAL_COUNT=3`, `ANNUALIZE_EXTRAPOLATED=YES` |
| CLAIMSUBMITLAG | `CLAIMSUBMITLAGAVAILABLE=FALSE` plus the `ADJ_*` column names used when it is on |
| SALES / USAGE | sale-lag distribution (`LOGNORMAL`) and profile parameter columns, `USAGEPROFILEBYVAR=VEHICLE_TYPE,DRIVE_TYPE,CUSTOMER_COUNTRY` |
| WARRANTYTYPE | `COMPLETESALESDATA=1`, `WARRANTYDIMENSION=2` |

So on this tenant "in service" means **registration date**, TIS bins are calendar months of
30.42 days, and a period is "mature" at 75 % exposure. Quote these from the tenant's file, not
from memory.

## analysis_param.csv and param_lookup.csv

`analysis_param.csv` (`Analysis_nm, Param_nm, Visibility_flg, Default_value, Param_lookup_nm,
Param_Label`) lists every UI parameter of **PARETO, TIMEOFCLAIM, TREND and TRENDEXP only**,
with `S` (shown) or `H` (hidden). Typical defaults: `analysisVar=CLAIMS.FAILURE_RATE`,
`reportVar=CLAIMS.OBJECT_CODE` (Pareto) or `CLAIMS.EVENT_MONTH` (Time of Claim),
`calcMethod=ASIS`, `tispointofview=frombuild`, `repairbeforesold=TRUE`, `numBars=20`,
`wrtyusagemaxmileage=36000`. Defaults for the other analyses live in the postcode program.

`param_lookup.csv` (`lookup_nm, lookup_val, order_no, lookupval_label`) supplies the dropdown
values: `ALERTSTATUS` (NEW, INPROGRESS, MONITOR, CLOSED, FMSACCEPTED), `calcMethod` (ASIS,
PROJECTED, EXTRAPOLATED), `DISTRIBUTION` (WEIBULL, EXPONENTIAL, LOGNORMAL, BIWEIBULL),
`maturitylevel` / `maxexpval` / `tisbinstodisplay` (0 to 60 months), `forecast_interval`,
`wrtyusagemaxmileage`, `RELIABILITYFITTYPE`, `IntrOctime`, `language`.
A dated copy (`param_lookup_20260601.csv`) differs only in composite `ALERTSTATUS_<value>`
names; keep the undated file as the active one.

## analysis_var.csv

`SOURCE_VAR_COMP_TXT, ANALYSIS_VAR_COMP_TXT, NUMERATOR_TXT, DENOMINATOR_TXT, column_name,
table_name`. Defines the computed measures per fact table and which other measures each one
may be combined with. Core definitions:

| Measure | Formula | Tables |
|---|---|---|
| `FAILURE_RATE` | `TOTALCLAIMCOUNT * 100 / SAMPLESIZE` | CLAIMS, SSD, DTC, NASYSDTC, WO |
| `TOT_EVENT_COUNT` | `TOTALCLAIMCOUNT` | same |
| `TOT_EVENT_COST`, `TOT_LBR_COST`, `TOT_PRT_COST`, `TOT_RBK_COST`, `TOT_THIRD_COST`, `TOT_LBR_HOURS`, `TOT_LABOR_UNITS` | sum of `EVENT_AMT`, `LABOR_AMT`, `PARTS_AMT`, `RBK_AMT`, `THIRD_PARTY_AMT`, `LABOR_HRS_TOTAL`, `LABOR_UNITS_TOTAL`; `_EVENT` variants divide by `TOTALCLAIMCOUNT`, `_UNIT` variants by `SAMPLESIZE` | CLAIMS |
| `LABOR_CODE_COUNT`, `LABOR_CODE_RATE`, `TOT_LABOR_COST`, `LABOR_UNITS_COUNT` | line-level | CLAIMSLABOR, WOLABOR |
| `CLAIM_PART_COUNT`, `CLAIM_PART_RATE`, `TOT_CLAIM_PART`, `TOTAL_PART_QTY` | line-level | CLAIMSPARTS, WOPARTS |

`FAILURE_RATE` is therefore claims per 100 units, where `SAMPLESIZE` is the unit count of the
data selection (adjusted for maturity when `calcMethod` is not ASIS).

## labels.csv

`name, text_en, text_de, group_name`; groups `table_meta`, `table_column_meta`,
`filter_attribute_group`, `template_param_lookup`. Loaded as user-defined formats
(`use_udf=Y`) and into the localization tables, so every UI label exists in English and German.
Missing labels show up as raw column names in the UI; precode generates them from the DEW
`LABEL` / `NOTES` columns.

## fr_failure_relationships.csv and fr_trivial_rules.csv

- `fr_failure_relationships.csv` (`TARGET_VAR_CD, COST_VAR_CD, SAME_VALUE_FLG_CD,
  TARGET_VAR_THRESHOLD_VALUE`): the columns Failure Relationships may mine. Reference tenant:
  17 targets (`CLAIM_PART_NUMBER`, `DAMAGE_CODE`, `DAMAGE_CODE_FULL`, `DTC`, `ECU_NAME`,
  `LABOR_CODE`, `LOCATION`, `MAN_PART_NUMBER`, `OBJECT_CODE`, `ORDER_PART_NUMBER`,
  `POSITION_CODE`, `PRIM_CLAIM_PART`, `PRIM_DAMAGED_PART`, `PRIM_INVOLVED_PART`,
  `PRIM_ORDER_PART`, `PRIM_REPAIRED_PART`, `SPN_NUMBER`), all with `SAME_VALUE_FLG_CD=0`
  (A to A relationships excluded) and threshold 5 (minimum support).
- `fr_trivial_rules.csv` (`target_var_cd, _l_hand_txt, _r_hand_txt`): rules to suppress;
  by default `? -> ALL` and `ALL -> ?` per target, i.e. anything involving the missing marker.

Preflight for Failure Relationships (preflight.md) should confirm the chosen domain column is in
this list; otherwise the analysis cannot be created.

## toc_report_var.csv

`report_var_nm, claim_period_nm, sale_period_nm, build_period_nm, interval_period_nm,
extrapolated_var_nm`. Maps each reporting period variable to its claim / sale / build
counterpart and interval (DAY, MONTH, QUARTER, NUMYEAR) for Time of Claim and Trend. Example:
`EVENT_MONTH` pairs with `REGISTRATION_MONTH` (sale) and `PRODUCTION_MONTH` (build). Only
`PRODUCTION_DATE/MONTH/QUARTER` carry an `extrapolated_var_nm`.

## geo.csv

`geo_code, latitude, longitude`; ISO 3166-1 alpha-2 country codes (about 1,200 rows including
sub-regions). `wrna_call_geo_load` warns for every value of a `GEOGRAPHIC` column that has no
coordinate. Country-level only: the Geographic analysis cannot go below country unless this
file is extended.

## Hand-maintained vs generated

| Generated by precode (edit the DEW) | Hand-maintained |
|---|---|
| `table_parameters.csv`, `column_parameters.csv`, `analysis_var.csv`, `labels.csv`, `fr_failure_relationships.csv`, `fr_trivial_rules.csv`, `toc_report_var.csv` | `parameters_*.txt`, `global_defaults.csv`, `analysis_param.csv`, `param_lookup.csv`, `geo.csv`, `IOTFORMATS.sashdat` (format library) |

After any change: run a config-only load (`parameters_configonly.txt`) so postcode refreshes
the Postgres metadata and the mid-tier cache.
