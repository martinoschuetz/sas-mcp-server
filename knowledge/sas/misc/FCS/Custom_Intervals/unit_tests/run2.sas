/**
 * Functionality: Run the Forecasting with Automatic Custom Interval Identification
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/

libname test "\\missrv01\f_public\custom_interval\testData";
libname temp1 "\\missrv01\f_public\custom_interval\temp\_temp1";
libname temp2 "\\missrv01\f_public\custom_interval\temp\_temp2";

/**
 * scenario 1: Family dollar whole data set with no dcc, use default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp1"
        args.inData="test.mfp_forecast_input1"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.byVars="CDIV_DESC CATEGORY_DESC DEPT_DESC CLASS_DESC SUBCLASS_DESC"
        args.outFor="work.outFor1"
        args.outModel="work.outModel1"
        args.patterGroupByVars="season_group_id"
        args.runGrouping = 0
        args.zeroDemandThresholdPct = 0.03
        args.idForecastMode = "AVG"
        args.start='"07JUN2008"d'
        args["end"]='"24AUG2013"d'
        args.lead=52
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;



/**
 * scenario 2: Family dollar whole data set with dcc, use default settings
*/
proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp2"
        args.inData="test.mfp_forecast_input1"
        args.idVar="EOW_DATE"
        args.idInterval="WEEK"
        args.demandVar="TOTAL_ADJ_SALES_AMT"
        args.byVars="CDIV_DESC CATEGORY_DESC DEPT_DESC CLASS_DESC SUBCLASS_DESC"
        args.outFor="work.outFor2"
        args.outModel="work.outModel2"
        args.runGrouping = 1
        args.zeroDemandThresholdPct = 0.03
        args.idForecastMode = "AVG"
        args.lead=52
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;
