libname test "\\missrv01\f_public\custom_interval\testData";
libname temp5 "\\missrv01\f_public\custom_interval\temp\_temp5";


proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp5"
        args.inData="test.Belkseasonaldept_active"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.byVars="mid_1 mid_2 mid_3 location_id mid_4 mid_5 mid_6 mid_7"
        args.outFor="work.outFor"
        args.outModel="work.outModel"
        args.runGrouping = 1
        args.zeroDemandThresholdPct = 0.15

        args["end"]='"30Dec2012"d' 
        args.lead=52
        args.align="B"
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;

proc sql noprint;
   create table temp5.outfor as
   select a.*,b.SLS_D_1 
   from outfor as a,
        test.Belkseasonaldept_active as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
         and a.mid_5=b.mid_5 and a.mid_6=b.mid_6 and a.mid_7=b.mid_7 
         and a.time_5=b.time_5
    order by mid_1, mid_2, mid_3, location_id, mid_4, mid_5, mid_6, mid_7, time_5;
quit;
data temp5.outmodel;
   set outmodel;
run;
proc sql noprint;
   create table temp5.outforall as
   select a.*,b._BEST_MODEL_INDEX, b._STS_TYPE, b._BEST_SCORE
   from temp5.outfor as a,
        temp5.outmodel as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
         and a.mid_5=b.mid_5 and a.mid_6=b.mid_6 and a.mid_7=b.mid_7
    order by mid_1, mid_2, mid_3, location_id, mid_4, mid_5, mid_6, mid_7, time_5;
quit;
