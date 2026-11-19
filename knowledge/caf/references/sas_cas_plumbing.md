# SAS Compute & CAS Plumbing for CAF Steps

Reference patterns for writing resilient, concurrency-safe SAS Viya / CAS background compute code in CAF `steps/<STEP_ID>.sas`.

---

## 1. Three Generations of CAF Plumbing (`[VERIFIED]`)

| Aspect | Generation 2 (Declarative — Preferred for Custom Single/Multi-Step) | Generation 1 (Explicit — `STABLEPERIOD` / Custom Cross-Step Lookups) | Generation 3 (`STANDARD` & `ALERTS` Only) |
| :--- | :--- | :--- | :--- |
| **Step Entry** | `%afi_caf_preprocess(?g_cas, ?analysisID);` | `%qas_getconnections(g_cas=?g_cas, g_metadata=?g_metadata);` + `%anl_getanalysisattributes(?analysisID);` | `%anl_driver(analysisID=?analysisID, g_cas=?g_cas, g_metadata=?g_metadata[, anlnm=...]);` |
| **Input Table** | `&g_caf_input_table` (automatically resolved in CAS) | `QASAnlOut.<PREFIX>_TRANSPOSE_&g_instance_nm` (built in Step 1 via `%anl_driver` or `SASTABLE` branch) | Pre-filtered `mycas.DS_PRODUCT`, `DS_CLAIM`, `DS_EVENT`, `DS_TAGS` |
| **Publishing Outputs** | `%let g_output_table_1 = work.SUMMARY;` ... `%afi_caf_postprocess;` (generated via `build_output_contract`) | Explicit `PROC CASUTIL` `promote` + `save` into `QASAnlOut`, followed by `PROC HTTP POST` to `/iotAnalysis/analyses/&G_INSTANCEID./steps/&G_ANALYSISID./outputParams?append=false` | Macro-managed `OUTPUTTABLENAME1..29`, `_LABEL`, `_FORMAT`, `alert_type`, `CHART_TYPE` |
| **Template Token Name** | Bare uppercase member name (`{{.SUMMARY}}`) | Exact `"outputname"` posted in `analysisStepOutputParams` (`{{.GIMPORTANCE_TABLE}}`, `{{.TS_TRANS_TABLE}}`) | Positional aliases `OUTPUTTABLENAME1..N` + `ANALYSISVAR1..15` |

> **Critical Reminders:**
> - Never place `?g_cas`, `?analysisID`, `?g_metadata`, `?limit`, `?append`, or `?filter` inside a comment anywhere in the `.sas` file — the mid-tier replaces only the **first** literal occurrence!
> - **Push Heavy Compute & Unpivots into CAS:** Keep correlations (`simple.correlation`), summary stats (`simple.summary`), `BY PAM_ASSET_ID DATETIME` persistence loops, and wide-to-long unpivoting (`array` loop in a CAS `DATA` step) inside 8-worker CAS rather than pulling hundreds of thousands of rows into SAS Compute `WORK` for `PROC SORT` / `PROC TRANSPOSE`. Always filter Step 3 scoring inputs (`&G_TIME_FILTER.` & selected assets) **before** standardising or joining raw rows.

---

## 2. CAS Table Naming & 32-Character Deterministic Asset Keys (`[VERIFIED]`)

SAS dataset/member names are strictly capped at **32 characters**, and `%qas_cas_output_lifetime` expects every instance table in `QASAnlOut` to end strictly with `_&g_instance_nm` (`9` chars, e.g. `_A995BD6E`).

If `<PREFIX>_` is `10` characters (e.g., `ISOLATION_`) and `_&g_instance_nm` is `9` characters, only **13 characters** remain for the middle segment (`32 - 10 - 9 = 13`). Embedding raw asset IDs like `IDCP_CH18B` (`10` chars) plus `_AST2` (`5` chars) produces `34` characters (`ISOLATION_IDCP_CH18B_AST2_A995BD6E`) and crashes SAS with `ERROR: Invalid data set name`!

**Solution:** Map any asset ID longer than 8 characters to a deterministic 8-character key (`substr(clean,1,4) || substr(CRC32(raw),1,4)`) and use `_M1` / `_M2` (`11` middle chars → `30 <= 32` chars guaranteed for **any** asset ID!):

```sas
%macro _caf_make_asset_key(in_macro_var, out_macro_var);
   data _null_;
      length _raw $256 _clean $256 _h $8 _key $8;
      _raw = strip(symget("&in_macro_var."));
      _clean = compress(_raw, "_", "ka");
      if length(_clean) = 0 then _clean = "ASSET";
      if length(_clean) <= 8 then _key = upcase(_clean);
      else do;
         _h = upcase(substr(strip(hashing("CRC32", _raw)), 1, 4));
         _key = cats(upcase(substr(_clean, 1, 4)), _h);
      end;
      call symputx("&out_macro_var.", _key);
   run;
%mend _caf_make_asset_key;
```

---

## 3. Self-Healing Step 1 CAS Pre-Cleanup (`[VERIFIED]`)

When Steps 2 or 3 promote custom CAS tables or save `.sashdat` files into `QASAnlOut`, re-running Step 1 invokes `%qas_cas_output_lifetime`, which can fail in `accessControl.updSomeAcsTable` if custom Step 2/3 tables still hold row/table ACS permissions.

Run an isolated `PROC CAS` pre-cleanup at the top of Step 1 **after** `%qas_getconnections` connects `mfgapp` (so you can compute the 8-char `CRC32` `shortId` of `analysis_ins_id`), saving and restoring `options sessref` so downstream macros are unaffected:

```sas
%macro _caf_preclean_instance_outputs(prefix);
   %local _prev_sess _ins_id _short_id;
   %let _prev_sess = %sysfunc(getoption(sessref));
   proc sql noprint;
      select strip(analysis_ins_id) into :_ins_id trimmed
      from mfgapp.analysis_ins_step
      where analysis_ins_step_id = "&G_ANALYSISID.";
   quit;
   data _null_;
      call symputx("_short_id", upcase(strip(hashing("CRC32", "&_ins_id."))));
   run;

   cas _clnsess sessopts=(caslib="QASAnlOut" timeout=60);
   proc cas;
      session _clnsess;
      table.tableInfo result=ti / caslib="QASAnlOut";
      if dim(ti, "TableInfo") > 0 then do r over ti.TableInfo;
         if index(upcase(strip(r.Name)), "&prefix._") = 1 and
            index(upcase(strip(r.Name)), "_&_short_id.") > 0 then do;
            table.dropTable / caslib="QASAnlOut" name=strip(r.Name) quiet=true remACs=true;
         end;
      end;
      table.fileInfo result=fi / caslib="QASAnlOut";
      if dim(fi, "FileInfo") > 0 then do f over fi.FileInfo;
         if index(upcase(strip(f.Name)), "&prefix._") = 1 and
            index(upcase(strip(f.Name)), "_&_short_id..SASHDAT") > 0 then do;
            table.deleteSource / caslib="QASAnlOut" source=strip(f.Name) quiet=true;
         end;
      end;
   run;
   quit;
   cas _clnsess terminate;
   %if %length(&_prev_sess.) > 0 %then %do;
      options sessref=&_prev_sess.;
   %end;
%mend _caf_preclean_instance_outputs;
```

---

## 4. Automatic `.sashdat` Reload Across Evicted CAS Sessions (`[VERIFIED]`)

Users frequently run Step 2 days after Step 1 (or Step 3 days after Step 2) after a CAS restart. Always save Step 1/2 outputs and ASTOREs as compressed `.sashdat` files in `QASAnlOut` and call `%_caf_ensure_cas_table` at the start of Steps 2 and 3:

```sas
%macro _caf_ensure_cas_table(tbl, caslib=QASAnlOut, sess=mySession);
   proc cas;
      session &sess.;
      table.tableExists result=te / caslib="&caslib." name="&tbl.";
      if te.exists = 0 then do;
         table.fileExists result=fe / caslib="&caslib." path="&tbl..sashdat";
         if fe.exists > 0 then do;
            table.loadTable / caslib="&caslib." path="&tbl..sashdat"
               casOut={caslib="&caslib." name="&tbl." promote=true};
         end;
      end;
   run;
   quit;
%mend _caf_ensure_cas_table;
```

---

## 5. Multi-Window `STABLEPERIOD` Parsing & Optional Blank Mode (`[VERIFIED]`)

1. **Read directly from `mfgapp.analysis_ins_step_input`:** Avoid `$100` character truncation in legacy helper macros when a user selects 3+ windows (`> 100` chars):
   ```sas
   proc sql noprint;
      select coalesce(param_value_txt, '') into :G_STABLE_PERIOD trimmed
      from mfgapp.analysis_ins_step_input
      where analysis_ins_step_id = "&G_ANALYSISID."
        and upcase(analysis_param_nm) = 'STABLE_PERIOD'; /* or 'SCORE_PERIOD' in Step 3 */
   quit;
   ```
2. **Parse 0, 1, or $k$ Windows Safely with `%superq`:**
   ```sas
   %global G_TIME_FILTER;
   %macro generate_time_filter;
      %local i G_STABLE_PART G_STABLESTART G_STABLEEND;
      %if not %symexist(G_STABLE_PERIOD) %then %let G_STABLE_PERIOD=;
      %let G_STABLE_PERIOD = %sysfunc(strip(%superq(G_STABLE_PERIOD)));

      %if %length(%superq(G_STABLE_PERIOD)) = 0 %then %do;
         %let G_TIME_FILTER = (1=1);
         %put NOTE: Period parameter is empty — using full asset history (1=1).;
         %return;
      %end;

      %let i = 1;
      %let G_TIME_FILTER =;
      %let G_STABLE_PART = %scan(%superq(G_STABLE_PERIOD), &i., %str(,));

      %do %until (%length(&G_STABLE_PART.) = 0);
         %let G_STABLESTART = %scan(%superq(G_STABLE_PART), 1, %str(-));
         %let G_STABLEEND   = %scan(%superq(G_STABLE_PART), 2, %str(-));
         %if &i. eq 1 %then
            %let G_TIME_FILTER = (DATETIME ge "&G_STABLESTART."dt and DATETIME le "&G_STABLEEND."dt);
         %else
            %let G_TIME_FILTER = &G_TIME_FILTER. or (DATETIME ge "&G_STABLESTART."dt and DATETIME le "&G_STABLEEND."dt);
         %let i = %eval(&i. + 1);
         %let G_STABLE_PART = %scan(%superq(G_STABLE_PERIOD), &i., %str(,));
      %end;
      %let G_TIME_FILTER = (&G_TIME_FILTER.);
   %mend generate_time_filter;
   ```
