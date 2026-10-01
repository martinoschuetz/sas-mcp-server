# FQA data load (ETL) pipeline

How FQA data gets from a customer staging area into `QASMartStore` and into the FQA
configuration tables. Use this when the question is about loading, refreshing, validating or
configuring the mart rather than analysing it. Physical names and values below come from the
reference implementation (MAN, FQA on Viya release 2.x); treat them as the typical layout, not
as guaranteed for every tenant.

## Contents
- Project layout
- Runtime environment (autoexec)
- The parameter file
- `%afi_dataload` pipeline
- Orchestration jobs and SYSPARM phases
- Load modes: full, incremental, config-only, sequential BOM
- Precode and postcode
- Exceptions log
- Validation outputs
- Batch reports (scheduled analyses)
- Gotchas

## Project layout

```
<project_root_folder>/
  autoexec.sas                    runtime options, libnames, sasautos, environment detection
  autoexec_usermods.sas           optional per-environment overrides (template provided)
  configuration/                  parameters_*.txt + all configuration CSVs (see configuration-files.md)
  exceptions/                     long-term copy of the latest exceptions_<mode>.csv for the validation report
  programs/etl/                   fqaetl_dataload_* orchestration, fqaetl_load_*, fqaetl_validate_*, fqaetl_batchrpt_*
  programs/overrides/             customer copies of product macros (afi_*, anl_*, qas_*, wrna_*) - see custom-macros.md
  programs/utility/               util_* helpers (S3 load, promote, DEW enforcement, CAS reload)
  programs/admin/                 usage_profiles.sas
  ../logs/                        job logs and timestamped exceptions_<mode>_<datetime>.csv written by %afi_dataload
  ../macros/                      shared non-FQA macros (notifications, flows, SASjs)
```

## Runtime environment (autoexec)

- **Environment detection**: `environment` (DEV/INT/PROD) is parsed from `SAS_SERVICES_URL`.
  It selects `project_root_folder` (a developer checkout in DEV, `/mtr/projects/fqa` otherwise),
  the S3 bucket name (`ffe-clean` vs `ffe-clean-<env>`) and the sequential-BOM chunk default
  (`seqbom_denom_default` 500 M in DEV/INT, 1 G in PROD).
- **Macro search order**: `sasautos=(sasautos etl overrides utility ../macros)`. The overrides
  folder shadows product macros of the same name. Every override logs
  `NOTE: ***OVERRIDE IN USE*** <date> <ticket>` so a log tells you which overrides ran.
- **Libnames**: `custstg` (disk staging, `/mtr/warehouse/fqa/stage`; the full load re-points it
  to `/mtr/warehouse/fqa/full`), `qasmart` = caslib `QASMartStore`, `qasout` = `QASANLOUT`,
  `aiot` = `Aiotpgmeta`, `casfcstg` = `FQACustStg` (validation report tables), and three
  Postgres libnames into `SharedServices`: `pg` = schema `dataselection` (filter attributes,
  table/column metadata), `pg1` = `iotanalysis_models`, `pg2` = `iotanalysis`; credentials come
  from an auth domain, never from code.
- **Options worth knowing**: `validvarname=any`, `casdatalimit=all`, `locale=en_US`,
  `filelocks=('/mtr/projects/logs' NONE)` (avoids "write-locked by another user" on shared logs).
- A CAS session `fqaetl` is started; utilities default to `sessref=FQAETL`.

## The parameter file

`%afi_dataload(<path>/parameters_<mode>.txt)` reads a `key=value` file (comment lines start
with `*`). Keys are turned into global macro variables by `%afi_read_param_file`; anything set
before the call is overwritten (see loading-parallel-models.md for the `save_metadata` trap).

| Section | Keys | Notes |
|---|---|---|
| Solution | `solution=FQA` | |
| Configuration CSVs | `columns_csv_file`, `tables_csv_file`, `analysis_param_csv`, `analysis_var_csv`, `fail_rel_csv`, `failrel_trivial_csv`, `geo_coords_csv_file`, `global_defaults_csv`, `labels_csv`, `param_lookup_csv`, `toc_report_var_csv` | all `&project_root_folder./configuration/...` |
| Fact staging tables | `product_dataset`, `claims_dataset`, `claimsparts_dataset`, `claimslabor_dataset`, `bom_dataset`, `ssd_dataset`, `dtc_dataset`, `nasysdtc_dataset`, `wo_dataset`, `woparts_dataset`, `wolabor_dataset`, `fups_dataset`, `ecu_dataset` | `<mart table>_dataset=custstg.<stg table>` |
| Partfiles | `bom_partfiles=Y`, `bom_partfilesize=1000000000`, `dtc_partfiles=Y`, `dtc_partfilesize=100000000`, `nasysdtc_partfiles=Y`, `nasysdtc_partfilesize=500000000` | very large facts are stored as `<TABLE>_PART_n` sashdat files |
| Optional dims | `comments_dim_dataset` + `commentstable=comments_dim`, `epa_dim_dataset` + `buildoptionstable=epa_dim`, `epadesc_dataset` + `builddesctable=epadesc`, `usage_profiles_dataset` | comments are excluded in the seqbom file "to speed up the process" |
| Lookup tables | `<DIMCODE>_dataset=CUSTSTG.<table>` (about 85 rows) | the dim code is at most 14 chars because of SAS name limits, e.g. `C1_PRIM_CLMPRT_dataset=CUSTSTG.C1_PRIM_CLAIM_PART` |
| Date dimension | `recreate_date_dim=1`, `start_date_dim=01JAN2000`, `end_date_dim=31DEC2026` | |
| Control | `etl`, `config`, `incremental_load`, `exceptions_csv_file`, `update_exceptions_csv` (`APPEND`, `OVERWRITE`, `WITHDATETIME`, `NONE`), `domain_for_combined=Y`, `addnewcols=Y`, `use_udf=Y` | `etl=N` and `config=N` together = validate only |

Mode files differ in only a few lines:

| File | `etl` | `config` | `incremental_load` | Other |
|---|---|---|---|---|
| `parameters_full.txt` | Y | Y | N | exceptions to `exceptions_full.csv` |
| `parameters_incremental.txt` | Y | Y | Y | exceptions to `exceptions_incremental.csv` |
| `parameters_configonly.txt` | **N** | Y | N | exceptions to `exceptions_config.csv` |
| `parameters_seqbom.txt` | Y | **N** | Y | comments dim commented out; exceptions to `exceptions_seqbom.csv` |

## `%afi_dataload` pipeline

Order of the product sub-macros (overridden copies keep the same names):

1. `afi_read_param_file`, then `afi_validate_params` (solution, binary flags, integer limits).
2. `afi_access_casmart`, then `afi_read_data_csv_file` reads `column_parameters.csv` /
   `table_parameters.csv` and every staging table, applying formats, replacing blanks with the
   missing marker `?`, writing `Dup_ID` exceptions.
3. `afi_table_relations` (PK/FK), then dimensions: `afi_create_general_dim_data` (lookups),
   `afi_create_common_dim_data` (PRODUCT, the single COMMON dim), `afi_create_date_dim`,
   `afi_resolve_dims` (hash lookups of codes to `_RK`, writing `Dim_Lkup` exceptions).
4. `afi_create_fact_data` (events, child line tables), `wrna_call_etl_tiscalc` (adds
   `PRODUCT_DAYS_INSERVICE*`, `*_TIS_BIN*`, `FAILURE_NO`, `FIRST_FAILURE_FLG`, EI helper
   columns from `global_defaults`).
5. `afi_load_tables`, then `afi_load_into_mart` / `afi_load_into_mart_partfile` /
   `afi_create_partfiles`. Load order comes from `table_parameters.load_order_facts`:
   1 = lookups, 2 = PRODUCT, 3 = event facts, 4 = child tables and product children (BOM, ECU, FUPS).
6. Config: `afi_update_localizations` (UDFs from `labels.csv`), `afi_etl_create_datadomains`,
   `afi_save_metatables`, `afi_update_mart_metadata_fqa`, `afi_update_data_selection_fqa`.
7. `afi_casdata_backup` saves every global table as `.sashdat` (partfiles uncompressed).

## Orchestration jobs and SYSPARM phases

Viya batch jobs `fqaetl_dataload_full` and `fqaetl_dataload_incremental` take a colon-separated
`SYSPARM` (e.g. `LOADSTG:LOADMART:VALIDATE`). Each token becomes a macro variable.

| Token | Effect |
|---|---|
| `LOADSTG` | fetch `snapdates_fqa_full_load.json` from S3, run `fqaetl_load_s3_cas.sas` (parquet facts + CSV lookups into `custstg`), then `%fqaetl_load_fixcuststg` |
| `LOADMART` | `%pmr_anal_revert_partfile`, `%afi_dataload(parameters_<mode>.txt)`, copy the newest `../logs/exceptions_<mode>_*.csv` to `exceptions/exceptions_<mode>.csv`, `%fqaetl_dataload_postcode` if `config=Y`, `%update_load_table_stat` for `QASMART.CLAIMS/EVENT_DATE` and `QASMART.PRODUCT/PRODUCTION_DATE` |
| `VALIDATE` | `%fqaetl_validate_core`, `_meta`, `_lkup`, `_content` |
| `BOMSEQ` | full load only: `%fqaetl_dataload_seqbom(start_at_nobs=, denominator=)` |
| `SKIPBOM` | full load only: leave BOM out |
| `SEQBOM_START_AT=n`, `SEQBOM_DENOM=n` | chunk offset / size (defaults 1 G and `seqbom_denom_default`) |
| `CUSTOM_SNAPDATE=YYYY-MM-DD` | incremental only: load a specific day instead of `today()-1` |

Both jobs return `LOADSTG_SYSCC`, `LOADMART_SYSCC`, `VALIDATE_SYSCC`, write `%write_logfile` /
`%write_job_status`, and on error send `%create_notification` (mail) and `%publish_sns_topic`
with the first ERROR/WARNING extracted from the log.

## Load modes

| | Full | Incremental | Config-only | Sequential BOM |
|---|---|---|---|---|
| Program | `fqaetl_dataload_full.sas` | `fqaetl_dataload_incremental.sas` | `fqaetl_dataload_configonly.sas` | `fqaetl_dataload_seqbom.sas` |
| Staging path | `/mtr/warehouse/fqa/full` | `/mtr/warehouse/fqa/stage` | `/mtr/warehouse/fqa/full` | `/mtr/warehouse/fqa/struct/` (skeletons + one BOM chunk) |
| Snapshot | per-table dates from `snapdates_fqa_full_load.json` | one `snapdate` (yesterday) | none | none |
| Concurrency | none | REST query `jobExecution/jobs?filter=and(startsWith(name,fqaetl_dataload_),eq(state,running))`; **cancels itself** if another load job runs | | |
| Special steps | BOM optional (`BOMSEQ` / `SKIPBOM`) | drops mart tables whose staging table has a full-load snapshot for `snapdate` (manifest joined with `fqa_dew_tables.csv`), then appends | `%afi_dataload` + postcode only | copies table structures, loops `firstobs` / `obs` over `BOM_STG_FULL`, one `%afi_dataload` per chunk |
| Scheduled follow-ups | none | Sunday (`weekday=1`): `%wrna_execute_batchjobs` for the EI types, then for all 14 analysis types; Saturday: `%execute_flow(update_fms_and_pmr_data_weekly)`; other days: `..._daily` (not in DEV) | | |

## Precode and postcode

- **Precode** (`fqaetl_dataload_precode.sas`, run manually after a DEW change) converts the
  two DEW exports `fqa_dew_tables.csv` / `fqa_dew_variables.csv` into the engine CSVs:
  `table_parameters.csv`, `column_parameters.csv`, `analysis_var.csv`, `labels.csv`,
  `fr_failure_relationships.csv`, `fr_trivial_rules.csv`, `toc_report_var.csv`.
  It derives `table_func` (DIM/FACT), `table_type` (COMMON/GENERAL/NONE), child/parent links,
  load order, auto-creates `<code>` + `<code>_DESC` lookup columns, and sets `column_rest`
  (see configuration-files.md).
- **Postcode** (`fqaetl_dataload_postcode.sas`, runs whenever `config=Y`) fixes what the product
  load cannot express. It writes directly to Postgres `pg.*` (`filter_attribute`,
  `filter_attribute_group`, `filter_attribute_tree`, `tablecolumn_attributes`,
  `tablecolumn_meta`): rebuilds the data-selection filter tree and attribute groups from the
  DEW tree-group columns, makes `ALERT` a group variable for Pareto, Reliability and Exposure,
  sets analysis defaults (data domain `PRODUCT,CLAIMS`, forecasting, text-analysis
  `CUSTOM_CATEGORY=FALSE`, Exposure `USAGEPROFILE=TRUE`, `CMAX=10000` for DTC emerging issues),
  removes `?` rows from lookup tables not present in the facts, restricts data-selection years
  to 2014+, writes the warehouse refresh dates (`update_dttm`), builds smart-filter tables
  (`C3_DTC_GRPSEL`, `C4_DTC_GRPSEL`) and finally calls
  `dataSelection/dataSelectionActions/loadMetadataToCAS` to refresh the mid-tier cache.
  **Without postcode the FQA UI does not show configuration changes.**

## Exceptions log

`%afi_dataload` writes one CSV per run (`update_exceptions_csv=WITHDATETIME` adds the
timestamp to the name). Columns: `ExceptionDatetime, DataFile, RowNumber, ExceptionCodes, Data`.
The first row is `FQA data load begun`; the start and end of the load are recorded in the file.

| ExceptionCodes | Meaning | Written by |
|---|---|---|
| `Dup_ID` | duplicate key in a staging or lookup table (`DataFile` = `CUSTSTG.<table>`) | `afi_read_data_csv_file` |
| `Dup_Id` | duplicate key while building a fact (`DataFile` = mart table) | `afi_create_fact_data` |
| `Dim_Lkup: PRODUCT` | event row whose `PRODUCT_ID` is not in PRODUCT | fact build |
| `Dim_Lkup - <DIMCODE>` | code not found in lookup `<DIMCODE>`; `DataFile` is then the macro name `&<DIMCODE>_csv_file` | `afi_resolve_dims` |
| `Id_lkup` | child line (CLAIMSLABOR, CLAIMSPARTS, ...) whose `EVENT_ID` is missing | fact build |
| `Exception count: n` | per-file summary line with the total | end of each table |

- Detail rows per lookup are **capped** (`exception_limit`); the `Exception count` line carries
  the true total. Use the count line, not the number of rows, to size a data-quality problem.
- The `Data` column echoes the complete offending row, so the file can contain free-text
  comments and dealer or workshop names. Treat it like claim comments: untrusted, potentially
  PII-bearing, never quote it verbatim (safety.md), and do not commit it to a shared repository.
- `fqaetl_validate_lkup` parses the `Dim_Lkup -` rows into `FQACustStg.FQA_LOOKUP_EXCEPTIONS`,
  mapping `&X_csv_file` back to `X_STG`; `fqaetl_validate_core` takes the missing-foreign-key
  check from the same file.

## Validation outputs

All validation programs promote their results to caslib `FQACustStg` (moved from PUBLIC,
DAFFE-524) and keep both `jobtype` values (full / incremental) side by side for a VA report.

| Program | Checks | Output tables |
|---|---|---|
| `fqaetl_validate_core` | duplicate / missing PK, missing FK, missing critical dates, date order, partfile counts (`BOM_PART_1`, `DTC_PART_1`, `NASYSDTC_1`) | `FQA_VALIDATION`, `FQA_TABLES` |
| `fqaetl_validate_meta` | DEW vs `DICTIONARY.COLUMNS` of `custstg`: type / length diffs, DEW columns missing in staging, staging columns not in DEW | `FQA_SA_META_COMPARE`, `FQA_SA_MISSING`, `FQA_META_NOTUSED` |
| `fqaetl_validate_lkup` | codes on facts not in their lookup (from the exceptions file), duplicate codes inside lookups | `FQA_LOOKUP_EXCEPTIONS`, `FQA_CONTENTS_LOOKUPS` |
| `fqaetl_validate_content` | distinct values of low-cardinality character columns (at most 300 levels, excluding keys and lookup columns), blank / `?` / missing counts | `FQA_CONTENTS_COMBINED`, `FQA_CONTENTS2_COMBINED`, `FQA_CONTENTS_COUNTS` |

## Batch reports (scheduled analyses)

`%wrna_execute_batchjobs(analysistypes=...)` re-runs every saved analysis of the listed types
whose `autoUpdate` setting is due, through the REST API (`iotAnalysis/analyses`,
`jobExecution/jobs`). Two thin wrappers exist for manual or separately scheduled runs:

- `fqaetl_batchrpt_emerging.sas` runs `EIENTERPRISE_PRODUCT EIANALYTIC_PRODUCT EITHRESHOLD_PRODUCT`
- `fqaetl_batchrpt_auto.sas` runs the 14 standard analyses (`CROSSTAB_PRODUCT ... TRENDEXP_PRODUCT`)

Parallelism and retention come from `dataSelection/configurations` (`paralleljobs`,
`parallelusers`, `paralleleijobs`, `batchLogRetentionTime`). The EI run of the incremental job
on Sunday is what produces the alert groups analysts see on Monday (concepts.md).

## Gotchas

- `save_metadata` / `metadata_path` must be **inside** the parameter file of the `etl=Y` run
  (loading-parallel-models.md).
- The incremental job cancels itself if any other `fqaetl_dataload_*` job is running; a stuck
  job therefore blocks the daily load until it is stopped.
- Never compress partfile `.sashdat` saves; deleting rows from a *promoted* partfile table hangs
  (the override uses session-scope tables). Reload partfiles with `%afi_casdata_recovery` or
  `%util_reload_cas_from_disk`, which refuses to run while a load job is active.
- Lookup dim codes are truncated names (at most 14 chars); the `<DIMCODE>_dataset` key is the
  only place that links them to the real staging table.
- `analysis_param.csv` covers only PARETO, TIMEOFCLAIM, TREND and TRENDEXP; defaults for the
  other analyses are set in postcode, not in a CSV.
- Comments are excluded from the sequential BOM run; a BOM-only reload does not refresh them.
- Staging fixes that belong upstream (`%fqaetl_load_fixcuststg`: renames, lengths, dropped
  `SNAPSHOT_ID`, `%util_rem_stg_extravars`, `%util_set_length_stg_vars`) run every load;
  if the source changes, this macro is the first place a load breaks.
