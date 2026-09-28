/**
 * Functionality: identify custom intervals (II)
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/
%let cmp_lib = work.ciFunc;
libname test "\\missrv01\f_public\custom_interval\testData";

/**
 * scenario 1: Easter series with default settings and debug=1
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_identification"]   = nil
        local id =require('fscb.customInterval.ci_identification')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="test.easter_toy_baskets"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray1"
        args.outScalar="work.outscalar1"
        args.zeroDemandThresholdPct = 0.005
        args["end"]= '"19Mar2011"d'
        args.lead=48
        args.idForecastCriterion = "MSE"
        args.debug=1

        rc=id.custom_interval_identification(args)
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
        package.loaded["fscb.customInterval.ci_identification"]   = nil
        local id =require('fscb.customInterval.ci_identification')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="test.easter_toy_avg"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray2"
        args.outScalar="work.outscalar2"
        args.zeroDemandThresholdPct = 0.005
        args.debug=0
        args["end"]= '"19Mar2011"d'
        args.lead=48

        rc=id.custom_interval_identification(args)
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
        package.loaded["fscb.customInterval.ci_identification"]   = nil
        local id =require('fscb.customInterval.ci_identification')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="test.Fall_winter_avg"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray3"
        args.outScalar="work.outscalar3"

        args.debug=1
        args.zeroDemandThresholdPct = 0.1
        args["end"]= '"18Feb2011"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52

        rc=id.custom_interval_identification(args)
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
        package.loaded["fscb.customInterval.ci_identification"]   = nil
        local id =require('fscb.customInterval.ci_identification')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="test.spring_summer_total"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.outArray="work.outarray4"
        args.outScalar="work.outscalar4"

        args.debug=0
        args.zeroDemandThresholdPct = 0.1
        args.idForecastCriterion = "MAE"
        args.idForecastMode = "AVG"
        args["end"]= '"18Feb2011"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52
        rc=id.custom_interval_identification(args)
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
        package.loaded["fscb.customInterval.ci_identification"]   = nil
        local id =require('fscb.customInterval.ci_identification')
        
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
        
        local args={}
        args.cmpLib=cmpLib
        args.inData="test.allcoats2"
        args.idVar="time_5"
        args.idInterval="WEEK"
        args.demandVar="SLS_D_1"
        args.outArray="work.outarray5"
        args.outScalar="work.outscalar5"
        args.byVars="mid_4"

        args.debug=1
        args.zeroDemandThresholdPct = 0.015
        args.idForecastCriterion = "MAE"
        args.idForecastMode = "AVG"
        args.idForecastMethod = "SEPARATE"
        args["end"]= '"30Nov2012"d'
        args.idForecastAccumulate = "AVG"
        args.lead=52
        rc=id.custom_interval_identification(args)
    endsubmit;
run;
%tst_log(indent=%str(    ),table=work.outscalar5);
%tst_log(indent=%str(    ),table=work.outarray5);
