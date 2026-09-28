libname test "D:\Codes\Forecasting\FCS\Custom_Intervals\testData";
/*libname test "\\missrv01\f_public\custom_interval\testData";*/

/*	package.path = "//dntsrc/yueli1/dev/mva-d4fwc141/fswbsrvr/misc/source/lua/?.lua;" .. package.path*/

proc lua restart;
	submit;
	package.path = "//germsz-2/D$/Codes/Forecasting/FCS/Custom_Intervals/customInterval/lua/?.lua;" .. package.path
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

		rc=ciRun.ci_forecast_run(args)
		endsubmit;
run;