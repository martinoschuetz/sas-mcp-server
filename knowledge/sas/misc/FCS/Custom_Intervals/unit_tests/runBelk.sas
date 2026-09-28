libname test "\\missrv01\f_public\custom_interval\testData";
libname temp4 "\\missrv01\f_public\custom_interval\temp\_temp4";


%let syscc=0;
data Belkseasonaldept;
   set test.Belkseasonaldept;
   if SLS_D_1 ne .;
run;
%dcc_class_wrapper(
   
   indata_table=Belkseasonaldept,
   time_id_var=time_5,
   demand_var=SLS_D_1,

   use_package=1,
   need_sort=1,

   hier_by_vars=%str(mid_1 mid_2 mid_3 location_id mid_4 mid_5 mid_6 mid_7),
   class_process_by_vars=,
   class_low_by_var=mid_7,
   class_high_by_var=,

   class_time_interval=WEEK,

   short_reclass=1,
   classify_deactive=1,

   debug=1,

   _class_merge_result_table=_class_merge_result_table
      );
data test.Belkseasonaldept_active;
   set _class_merge_result_table;
   if DC_BY ne "DEACTIVE" and DC_BY ne "SHORT";
run;



proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp4"
        args.inData="test.Belkseasonaldept_active"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.byVars="mid_1 mid_2 mid_3 location_id mid_4 mid_5 mid_6 mid_7"
        args.outFor="work.outFor"
        args.outModel="work.outModel"
        args.runGrouping = 1
        args.zeroDemandThresholdPct = 0.15
        args.idForecastMode = "AVG"
        args["end"]='"30Jun2013"d' 
        args.lead=26
        args.align="B"
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;

proc sql noprint;
   create table temp4.outfor as
   select a.*,b.SLS_D_1 
   from outfor as a,
        test.Belkseasonaldept as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
         and a.mid_5=b.mid_5 and a.mid_6=b.mid_6 and a.mid_7=b.mid_7 
         and a.time_5=b.time_5
    order by mid_1, mid_2, mid_3, location_id, mid_4, mid_5, mid_6, mid_7, time_5;
quit;
data temp4.outmodel;
   set outmodel;
run;
proc sql noprint;
   create table temp4.outforall as
   select a.*,b._BEST_MODEL_INDEX, b._STS_TYPE, b._BEST_SCORE
   from temp4.outfor as a,
        temp4.outmodel as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
         and a.mid_5=b.mid_5 and a.mid_6=b.mid_6 and a.mid_7=b.mid_7
    order by mid_1, mid_2, mid_3, location_id, mid_4, mid_5, mid_6, mid_7, time_5;
quit;
