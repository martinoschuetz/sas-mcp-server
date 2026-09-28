/**
 * Functionality: Run the Forecasting with Automatic Custom Interval Identification
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/

libname test "\\missrv01\f_public\custom_interval\testData";

/**
 * scenario 1: One Easter series with no dcc, use default settings and debug=1
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.inData="test.easter_toy_baskets"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outFor="work.outFor1"
        args.outModel="work.outModel1"
        args.runGrouping = 0
        args.zeroDemandThresholdPct = 0.005
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;

%tst_log(indent=%str(    ),table=work.outModel1);
%tst_log(indent=%str(    ),table=work.outFor1);


/**
 * scenario 2: One Easter series with no dcc, use default settings and debug=0
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.inData="test.easter_toy_avg"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outFor="work.outFor2"
        args.outModel="work.outModel2"
        args.runGrouping = 0
        args.zeroDemandThresholdPct = 0.005
        args["end"]= '"18Feb2012"d'
        args.debug=0

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outModel2);
%tst_log(indent=%str(    ),table=work.outFor2);

/**
 * scenario 3: One Fall/Winter series with no dcc, use most default settings, holdout, and debug=0
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        

        
        local args={}
        args.inData="test.Fall_winter_avg"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outFor="work.outFor3"
        args.outModel="work.outModel3"
        args.debug=0
        args.zeroDemandThresholdPct = 0.1
        args["end"]= '"18Feb2011"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outModel3);
%tst_log(indent=%str(    ),table=work.outFor3);

proc sql noprint;
    create table outFor3_merge as
    select a.*, b.TOTAL_ADJ_SALES_AMT
    from outFor3 as a,
         test.Fall_winter_avg as b
    where a.EOW_DATE=b.EOW_DATE
    order by EOW_DATE;
run;
quit;

/**
 * scenario 4: One Spring/Summer series with no dcc, use most default settings, future, and debug=0
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.inData="test.spring_summer_total"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outFor="work.outFor4"
        args.outModel="work.outModel4"

        args.debug=0
        args.zeroDemandThresholdPct = 0.1
        args.idForecastCriterion = "MAE"
        args.idForecastMode = "AVG"
        args.idForecastAccumulate = "AVG"
        args["end"]= '"18Feb2012"d'
        args.lead=26
        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outModel4);
%tst_log(indent=%str(    ),table=work.outFor4);


/**
 * scenario 5: Belk seasoanl series with by-variables, no dcc, use most default settings, future, and debug=1
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.inData="test.allcoats2"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.outFor="work.outFor5"
        args.outModel="work.outModel5"
        args.byVars="mid_2 mid_3 mid_4"
        args.patterGroupByVars="mid_2 mid_3 mid_4"
        args.fcstByVar="mid_4"
        args.runGrouping = 0
        args.zeroDemandThresholdPct = 0.15
        args.debug=1
        args.idForecastMode = "AVG"
        args.idForecastCriterion = "MAE"
        args.idForecastMethod = "SEPARATE"
        args.idForecastAccumulate = "AVG"
        args["end"]= '"30Nov2013"d'
        args.lead=52
        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outModel5);
%tst_log(indent=%str(    ),table=work.outFor5);

