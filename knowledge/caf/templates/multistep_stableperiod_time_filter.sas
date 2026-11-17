/* Reusable Multi-Step STABLEPERIOD CAF SAS Macro Toolkit
   1. %_caf_preclean_instance_outputs(prefix)  - Self-healing Step 1 CAS pre-cleanup (remACs=true + .sashdat)
   2. %_caf_ensure_cas_table(tbl)              - Auto-reload evicted .sashdat tables/ASTOREs in Steps 2+
   3. %_caf_make_asset_key(invar, outvar)      - Deterministic <=8-char CRC32 asset key (keeps names <= 32 chars)
   4. %_caf_build_time_filter(param_nm, outvar)- Safe 0/1/multi-window STABLEPERIOD filter via %superq
*/

/* 1. Call at the top of Step 1 (after %qas_getconnections connects mfgapp) */
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

/* 2. Call at the top of Steps 2 and 3 to reload evicted CAS tables/ASTOREs from .sashdat */
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

/* 3. Build deterministic <=8-char asset key so <PREFIX>_<KEY8>_M1_<shortId> <= 32 chars */
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

/* 4. Read STABLE_PERIOD or SCORE_PERIOD without $100 truncation and support 0, 1, or k windows */
%macro _caf_build_time_filter(param_nm, out_filter_var);
   %local _raw_periods _i _part _start _end _flt;
   %let _raw_periods =;
   proc sql noprint;
      select coalesce(param_value_txt, '') into :_raw_periods trimmed
      from mfgapp.analysis_ins_step_input
      where analysis_ins_step_id = "&G_ANALYSISID."
        and upcase(analysis_param_nm) = "%upcase(&param_nm.)";
   quit;
   %let _raw_periods = %sysfunc(strip(%superq(_raw_periods)));

   %if %length(%superq(_raw_periods)) = 0 %then %do;
      %let &out_filter_var. = (1=1);
      %put NOTE: &param_nm. is empty — defaulting filter to (1=1).;
      %return;
   %end;

   %let _i = 1;
   %let _flt =;
   %let _part = %scan(%superq(_raw_periods), &_i., %str(,));
   %do %until (%length(&_part.) = 0);
      %let _start = %scan(%superq(_part), 1, %str(-));
      %let _end   = %scan(%superq(_part), 2, %str(-));
      %if &_i. = 1 %then
         %let _flt = (DATETIME ge "&_start."dt and DATETIME le "&_end."dt);
      %else
         %let _flt = &_flt. or (DATETIME ge "&_start."dt and DATETIME le "&_end."dt);
      %let _i = %eval(&_i. + 1);
      %let _part = %scan(%superq(_raw_periods), &_i., %str(,));
   %end;
   %let &out_filter_var. = (&_flt.);
%mend _caf_build_time_filter;
