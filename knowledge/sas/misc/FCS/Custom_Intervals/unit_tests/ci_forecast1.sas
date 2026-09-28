/**
 * Functionality: Find best forecast based on identify custom intervals (II)
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/
%let cmp_lib = work.ciFunc;
%let path=&dc_playpen_path.\fswbsrvr\unit_tests\custom_interval\ci_identify2_work;
libname idRes "&path";

%macro add_index();
    %do i=1 %to 4;
        data idRes.outarray&i;
            set idRes.outarray&i;
            drop _SEAON_INDEX;
            _SEASON_INDEX=week(EOW_DATE);
        run;
     %end;
%mend;
%add_index;

/**
 * scenario 1: Easter series with default settings and debug=1
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
        args.debug=0

        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar1);
%tst_log(indent=%str(    ),table=work.outarray1);



/**
 * scenario 2: Easter series with default settings and no debug
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
        args.debug=1
        
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar2);
%tst_log(indent=%str(    ),table=work.outarray2);

/**
 * scenario 3: Fall/Winter series with most default settings and debug=1
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
        args["end"]= '"18Feb2012"d'
        args.idForecastAccumulate = "AVG"
        args.lead=26

        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar3);
%tst_log(indent=%str(    ),table=work.outarray3);

/**
 * scenario 4: Spring/Summer series with most default settings and debug=0
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
        args["end"]= '"18Feb2012"d'
        args.idForecastCriterion = "MAE"
        args.idForecastAccumulate = "AVG"
        args.lead=26
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar4);
%tst_log(indent=%str(    ),table=work.outarray4);

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
        args["end"]= '"30Nov2013"d'
        args.idForecastCriterion = "MAE"
        args.idForecastMethod = "SEPARATE"
        args.idForecastAccumulate = "AVG"
        args.lead=26
        rc=fcst.custom_interval_forecast(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar5);
%tst_log(indent=%str(    ),table=work.outarray5);
