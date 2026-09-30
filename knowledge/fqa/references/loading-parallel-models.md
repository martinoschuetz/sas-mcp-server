# Loading Parallel Data Models in AIoT (FQA and APA)

When running the data load process for multiple AIoT solutions (such as Field Quality Analytics - FQA and Asset Performance Analytics - APA) in parallel, certain architectural constraints regarding the central `AIoTPgMeta.table_meta_pg` registry and `.sas7bdat` physical metadata files must be taken into account.

## The Metadata Saving Mechanism (`save_metadata=Y`)

In the AIoT data load macros (e.g., `%afi_dataload`), the parameter `save_metadata=Y` governs whether a solution's configuration and refresh dates are exported to physical SAS datasets (`*_fqa.sas7bdat` or `*_apa.sas7bdat`) in the central `metadata_path`. 

1. **ETL Phase (`etl=Y`) vs Configuration Phase (`etl=N`)**
   - The `TABLE_META_REFRESH_DATES` dataset (which stores the critical `last_data_dttm` timestamps for each table) is **only** generated and populated during the data extraction and load phase (`etl=Y`). 
   - If a script is split into an initial `etl=Y` run without `save_metadata=Y` and a subsequent `etl=N` config-only run with `save_metadata=Y`, the metadata files will be successfully exported, but the `TABLE_META_REFRESH_DATES` file will be completely missing (since `etl=N` skips the logic that creates those timestamps).
   - **Rule:** Always ensure that `save_metadata=Y` and `metadata_path=...` are physically present inside the parameter file used for the `etl=Y` phase (e.g., `Load_Demo_Data_params_orig.txt`). Setting them globally at the top of the `.sas` script will not work, as `%afi_read_parameters` clears and re-initializes these variables from the text file.

## The Race Condition on Postgres `table_meta_pg`

The physical `.sas7bdat` files from different solutions (e.g., `*_apa.sas7bdat` and `*_fqa.sas7bdat`) do not overwrite each other in the `Metadata` folder because they have different suffixes. Running FQA and APA loads in parallel to generate these files is perfectly safe.

However, the final step of the loading process often involves merging the contents of this `Metadata` folder and pushing them into the Postgres database (`AIoTPgMeta.table_meta_pg`).
- If both the APA script and the FQA script automatically execute the Postgres merge/population macro (e.g., `%afi_populate_pg_meta` or via `reload_fqa_metadata_tool`) at the end of their runs, a **race condition** occurs.
- The two parallel jobs will attempt to write to the central `AIoTPgMeta` caslib simultaneously. The job that finishes last will overwrite the other's metadata, leading to one solution's tables completely disappearing from the AIoT UI or having missing timestamps.

## Best Practices for Loading Multiple Models

To safely load FQA and APA in parallel:
1. **Disable Auto-Populate in Parallel Scripts:** Ensure that the individual data load scripts for FQA and APA do not automatically attempt to write to Postgres. They should only export their respective `.sas7bdat` files to the shared `metadata_path`.
2. **Include Metadata Parameters in `etl=Y`:** Ensure `save_metadata=Y` is hardcoded in the primary ETL parameter file for both solutions so that `table_meta_refresh_dates` is generated correctly.
3. **Run a Unified Merge Step at the End:** Once both parallel loads have finished exporting their `.sas7bdat` files to the `Metadata` folder, run a single, separate, sequential step (such as calling the reload metadata tool or the `%afi_populate_pg_meta` macro) to combine all the files and update Postgres centrally.
