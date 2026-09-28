libname test "\\missrv01\f_public\custom_interval\testData";
libname temp8 "\\missrv01\f_public\custom_interval\temp\_temp8";

proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp8"
        args.inData="test.Belkseasonaldept_active"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.byVars="mid_1 mid_2 mid_3 location_id mid_4"
        args.outFor="work.outFor"
        args.outModel="work.outModel"
        args.runGrouping = 0
        args.patterGroupByVars = "mid_1 mid_2 mid_3 location_id mid_4"
        args.zeroDemandThresholdPct = 0.09
        args.idForecastMode = "AVG"

        args["end"]='"30Dec2012"d' 
        args.lead=52
        args.align="B"
        args.eventPeriodLenThreshold = 6
        args.inSeasonRule="MAX"
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;

proc sql noprint;
   create table Belkseasonaldept as
   select distinct mid_1, mid_2, mid_3, location_id, mid_4, time_5, sum(SLS_D_1) as SLS_D_1
   from test.Belkseasonaldept_active
   group by mid_1, mid_2, mid_3, location_id, mid_4, time_5
   order by mid_1, mid_2, mid_3, location_id, mid_4, time_5;

   create table temp8.outfor as
   select a.*,b.SLS_D_1 
   from outfor as a,
        Belkseasonaldept as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
         and a.time_5=b.time_5
    order by mid_1, mid_2, mid_3, location_id, mid_4, time_5;
quit;
data temp8.outmodel;
   set outmodel;
run;
proc sql noprint;
   create table temp8.outforall as
   select a.*,b._BEST_MODEL_INDEX, b._STS_TYPE, b._BEST_SCORE
   from temp8.outfor as a,
        temp8.outmodel as b
   where a.mid_1=b.mid_1 and a.mid_2=b.mid_2 and a.mid_3=b.mid_3
         and a.location_id=b.location_id and a.mid_4=b.mid_4 
    order by mid_1, mid_2, mid_3, location_id, mid_4, time_5;
quit;
