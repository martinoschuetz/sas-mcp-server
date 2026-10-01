# Custom macro layer: overrides, utilities, admin

FQA customers ship a layer of SAS macros next to the product. Knowing it matters when a log
shows unexpected behaviour, when a load has to be repaired, or when a user asks "why does the
UI do X". Names and tickets are from the reference implementation (MAN); the pattern is the
same elsewhere.

## Contents
- How overrides work
- Override catalog
- Utility macros
- Admin: usage profiles
- Program header convention

## How overrides work

`autoexec.sas` puts `programs/overrides` into `sasautos` **after** the product autocall
library, so a file with the same name as a product macro replaces it for every job. Each
override announces itself:

```
%put NOTE: ***OVERRIDE IN USE*** 27MAY2026 FQA-11314;
```

Grep a job log for `OVERRIDE IN USE` to see which customised macros ran. Ticket prefixes:
`FQA-nnnn` = product defect, `IIOTTRIAGE-nnn` = SAS support triage, `DAFFE-nnn` = customer
project Jira. Not every override carries the marker (8 of 30 do not).

## Override catalog

### Data load (`afi_*`)

| Macro | Why it is overridden |
|---|---|
| `afi_read_param_file`, `afi_validate_params` | parameter parsing; accepts `AIOT` as alias for `APA`; validates binary and integer keys |
| `afi_read_data_csv_file` | FQA-12013: `column_parameters` support, SAS Drive URIs, stored dimension paths for incremental, `domain_for_combined`, epoch datetime conversion |
| `afi_create_general_dim_data`, `afi_create_common_dim_data`, `afi_create_transpose_dim_data` | FQA-11314 plus "new attributes" issue: hierarchy support, dimension caching (`dimpath.*`, `<table>_store=Y`), format-mismatch detection between CSV and existing CAS table, missing-value row (`RK=0`) |
| `afi_resolve_dims` | hash-based code to `_RK` lookup writing `Dim_Lkup` exceptions |
| `afi_create_fact_data` | multi-solution (FQA / APA / PQA) fact build, exception counting |
| `afi_create_partfiles` | BOM as partfiles (02JUL2025): appends to the last `PART_n` while it is below 1.5 x `partfilesize`; needs `%_PART_%` pattern to tell `CLAIMS_PARTS` from `CLAIMS_PART_1` |
| `afi_load_tables` | FQA-11314: load order by solution, adds `geo_coords` and `variable_lookups` |
| `afi_load_into_mart` | FQA-9990: computes `FIRST_FAILURE_FLG` and `FAILURE_NO` from `ANALYSIS_GLOBAL_DEFAULTS` |
| `afi_load_into_mart_partfile` | FQA-9990 + partfiles + `combinedomain` on incremental; 01SEP2026: use a **session-scope** table because deleting rows from a promoted table hangs |
| `afi_casdata_backup` | 10JUL2025: no `compress=true` on `table.save` (kills partfile performance) |
| `afi_casdata_recovery` | reload every `.sashdat` and `PARTFILE_RANGE` from the caslib path with `promote=true` |
| `afi_bootstrap_localizations` | FQA-11667: localization API calls for all analysis product groups |

### Analysis runtime (`anl_*`, `qas_*`, `wrna_*`)

| Macro | Why it is overridden |
|---|---|
| `anl_override_attributes` | DAFFE-273: `ValueLimit` 100 to 2000 for FMS-integration analyses (`_FMS_measures` in the instance name); parses `alt_date=DDMONYYYY:HH:MM:SS` from the analysis **description** to run as of a historical refresh date |
| `anl_override_data` | with `alt_date`: recomputes days in service and TIS bins and drops events after the cut-off |
| `anl_textanalysisoutput`, `anl_reliabilityoutput` | FQA-10562: CAS `textManagement.identifyLanguage` on lower-cased comments before topic mining (German / English mix) |
| `qas_getconnections` | CAS + Postgres (`mfgapp`) connections from REST / Consul, loads `*_PG` metadata tables to `AIoTPgMeta` |
| `qas_getfiltereddata` | data-selection subset creation with dimension joins (large, customer-specific) |
| `qas_cas_output_lifetime`, `qas_load_delete_sashdat` | IIOTTRIAGE-320: analysis output tables get a CAS lifetime (default 259200 s), deny-all ACLs with grants to `qasAppAdmin`, `SASAdministrators`, `sasapp` and the owner, column-level restrictions from `rest_users` / `rest_calcvars`, and are saved as `.sashdat`; load / delete by instance name (`EIDHT`, `EIENT` prefixes) |
| `wrna_getdata` | FQA-11321, IIOTTRIAGE-320: removes restricted calculation variables for restricted user groups |
| `wrna_call_etl_tiscalc` | 08AUG2026: `FIRST_FAILURE_FLG` as a Detail analysis variable; adds TIS, claim-submit-lag and EI helper columns (`__INALERT__`, `BUILD_PERIOD`, `INSERVICE_PERIOD`) |
| `wrna_call_geo_load` | FQA-11314: warns on geographic codes without coordinates |
| `wrna_runbatchjobs` | FQA-11668: batch settings from `dataSelection/configurations`, analyses filtered by owner and type, job polling every 3 s up to 9 min |
| `wrna_checkeijob_status` | IIOTTRIAGE-352: waits up to 360 x 10 s for EI sub-jobs (30+ min runs) |
| `wrna_eienterpriseoutput`, `wrna_eienterpriserunlevel` | IIOTTRIAGE-340 / 352: skip post-processing when sub-jobs produced no tables; tolerate `PROC RELIABILITY` floating-point errors; format counts of the `wumeeker` table |

Implications for an analyst agent:
- An analysis whose description contains `alt_date=` is **not** computed on the current refresh
  date. Check descriptions before comparing numbers (concepts.md: descriptions are data).
- Restricted users may see fewer calculation variables than the configuration lists.
- Analysis output tables in `QASANLOUT` expire after their lifetime unless re-run; an empty or
  missing table may simply have aged out.

## Utility macros

| Macro / program | Purpose | Used by |
|---|---|---|
| `%util_load_parquet_to_cas(incaslib=, casout=, nobs=, compress=, custstg_out=)` | S3 parquet (partitioned by `snap=<date>`) to CAS to `custstg` | `fqaetl_load_s3_cas` (14 fact tables) |
| `%util_load_csv_to_cas(casdata=, idformat=, decformat=, comblkp=, adddec=, ...)` | S3 CSV lookup to `custstg`; `comblkp=Y` for combined lookups (DAFFE-523), `adddec=Y` for extra description columns (DAFFE-670) | `fqaetl_load_s3_cas` (about 70 lookups), postcode |
| `%util_promote_to_cas(casdata=, incaslib=, outcaslib=, sessref=FQAETL)` | drop, save, promote a session table | validation programs, postcode |
| `%util_rem_stg_extravars(lib=CUSTSTG)` | drop staging columns not in the DEW | `fqaetl_load_fixcuststg` |
| `%util_set_length_stg_vars(lib=CUSTSTG)` | `ALTER TABLE ... MODIFY` character lengths to the DEW | `fqaetl_load_fixcuststg` |
| `%util_reload_cas_from_disk` | reload `FQACustStg` (and via `%afi_casdata_recovery` the mart) from `.sashdat`; **exits if a `fqaetl_dataload_*` job is running** | operations |
| `%reload_caslib(caslib=, l_tablename=, memoryFormat=)` | reload one table (e.g. BOM with DVR) | operations |
| `%unload_all_tables_caslib(caslib=)` | drop every table of a caslib before a recovery | operations |
| `util_format_save_to_disk.sas`, `util_format_load_from_disk.sas`, `util_format_list.sas` | save / restore / list the `IOTFORMATS` CAS format library (`casfmts` caslib on `/mtr/tmp`) | operations |
| `%util_change_ds_locale(locale=de-DE)` | clears analysis and data-selection caches and re-reads the filter tree in a locale | `fqaetl_validate_content` |
| `%s3_list_files(S3_BUCKET=)` | recursive S3 listing into `WORK.FILE_DICTIONARY_S3_BUCKET` | discovery |
| `util_program_to_create_job.sas` | registers a program as a Viya job via SASjs `%mv_createjob` (path `/MTR/fqa/jobs`, context `qasComputeContext`) | deployment |
| `perf_test_simple.sas`, `perf_test_iteration.sas` | 1 G-row I/O benchmarks with `fullstimer` | sizing |

## Admin: usage profiles

`programs/admin/usage_profiles.sas` is the product administration program for **usage
profiles** (mileage or hours accumulation per unit group, used by Exposure and by the
`usageprofile` analysis option). Modes: `EXPLORE` (pull recent mart data and fit statistics),
`BUILD` (create profile parameter tables from the groupings), `GRAPH` (compare fitted vs actual),
`PUBLISH` (copy to the ETL staging location as `usage_profiles` / `usage_profstats`), `UPDATE`
(refresh assignments without refitting). The load picks the published tables up through
`usage_profiles_dataset=custstg.usage_profiles`; grouping variables are
`USAGEPROFILEBYVAR` in `global_defaults.csv`.

## Program header convention

Every customer program starts with a fixed header block: program name and type, author,
storage folder, description, called by, pre-requisites, parameters (mandatory / optional with
defaults), input and output tables, and a dated **change history** table with name, date,
description. The change history is the only changelog; there is no central one. Ticket numbers
in those rows (`DAFFE-nnn`) are the way to trace why a line of code exists.
