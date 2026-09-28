/**
 * Functionality: Find best forecast based on identify custom intervals (II)
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/
%let cmp_lib = work.ciFunc;
%let path=&dc_playpen_path.\fswbsrvr\unit_tests\custom_interval\ci_identify3_work;
libname idRes "&path";
libname test "\\missrv01\f_public\custom_interval\testData";

/**
 * scenario 1: Easter series with default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_forecast"]   = nil
        local fcst =require('fscb.customInterval.ci_forecast')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="idRes.outarray1"
        args.inScalar="idRes.outscalar1"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray1"
        args.outScalar="work.outscalar1"
        args.idForecastCriterion = "MSE"
        args["end"]= '"19Mar2011"d'
        args.lead=48
        args.debug=0

        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;

%tst_log(indent=%str(    ),table=work.outscalar1);
%tst_log(indent=%str(    ),table=work.outarray1);

proc sql noprint;
    create table outarray1_merge as
    select a.*, b.TOTAL_ADJ_SALES_AMT
    from outarray1 as a,
         test.easter_toy_baskets as b
    where a.EOW_DATE=b.EOW_DATE
    order by EOW_DATE;
run;
quit;


/**
 * scenario 2: Easter series with default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_forecast"]   = nil
        local fcst =require('fscb.customInterval.ci_forecast')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="idRes.outarray2"
        args.inScalar="idRes.outscalar2"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray2"
        args.outScalar="work.outscalar2"
        args["end"]= '"19Mar2011"d'
        args.lead=48        
        args.debug=1
        
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar2);
%tst_log(indent=%str(    ),table=work.outarray2);

proc sql noprint;
    create table outarray2_merge as
    select a.*, b.TOTAL_ADJ_SALES_AMT
    from outarray2 as a,
         test.easter_toy_avg as b
    where a.EOW_DATE=b.EOW_DATE
    order by EOW_DATE;
run;
quit;

/**
 * scenario 3: Fall/Winter series with most default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_forecast"]   = nil
        local fcst =require('fscb.customInterval.ci_forecast')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="idRes.outarray3"
        args.inScalar="idRes.outscalar3"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray3"
        args.outScalar="work.outscalar3"

        args.debug=1
        args["end"]= '"18Feb2011"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52

        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar3);
%tst_log(indent=%str(    ),table=work.outarray3);

proc sql noprint;
    create table outarray3_merge as
    select a.*, b.TOTAL_ADJ_SALES_AMT
    from outarray3 as a,
         test.Fall_winter_avg as b
    where a.EOW_DATE=b.EOW_DATE
    order by EOW_DATE;
run;
quit;

/**
 * scenario 4: Spring/Summer series with most default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_forecast"]   = nil
        local fcst =require('fscb.customInterval.ci_forecast')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="idRes.outarray4"
        args.inScalar="idRes.outscalar4"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray4"
        args.outScalar="work.outscalar4"

        args.debug=0
        args.idForecastCriterion = "MAE"
        args.idForecastMode = "AVG"
        args["end"]= '"18Feb2011"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar4);
%tst_log(indent=%str(    ),table=work.outarray4);

proc sql noprint;
    create table outarray4_merge as
    select a.*, b.TOTAL_ADJ_SALES_AMT
    from outarray4 as a,
         test.spring_summer_total as b
    where a.EOW_DATE=b.EOW_DATE
    order by EOW_DATE;
run;
quit;

/**
 * scenario 5: Belk seasoanl series with by-variables
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_forecast"]   = nil
        local fcst =require('fscb.customInterval.ci_forecast')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="idRes.outarray5"
        args.inScalar="idRes.outscalar5"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.outArray="work.outarray5"
        args.outScalar="work.outscalar5"
        args.byVars="mid_4"
        args.scalarByVars="mid_4"

        args.debug=1
        args.idForecastCriterion = "MAE"
        args.idForecastMethod = "SEPARATE"
        args["end"]= '"30Nov2012"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar5);
%tst_log(indent=%str(    ),table=work.outarray5);

proc timedata data=test.allcoats2 out=allcoats2;
   id time_5 interval=week accumulate=total align=E;
   var SLS_D_1;
   by mid_4;
run;
proc sql noprint;
    create table outarray5_merge as
    select a.*, b.SLS_D_1
    from outarray5 as a,
         allcoats2 as b
    where a.mid_4=b.mid_4 and a.time_5=b.time_5 
    order by mid_4, time_5;
run;
quit;
