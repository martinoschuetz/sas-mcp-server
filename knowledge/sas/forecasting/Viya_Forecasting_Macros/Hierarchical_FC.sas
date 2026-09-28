*options source source2 mprint mlogic;

/****************************************************************/
/* Modul: Hierarchical-Forcasting 								*/
/*		  (Auto-Forcasting with Reconciliation)					*/
/*																*/
/* Input:														*/
/* 		_LIB_IN: 	Data input library							*/
/* 		_LIB_OUT: 	Data output library							*/
/*		_FILE:		file to foreast								*/
/*		_VAR:		forecast variable							*/
/*		_DATE:		time variable (interval=MONTH) 				*/
/*		_BY1:		segment variable level 1					*/
/*		_BY2:		segment variable level 2					*/
/*		_HORIZON:	first forecast month						*/
/*		_LEVEL:		reconciliation level top-down (std=0)		*/
/*					_level=0: reconciliation top-_by1-_by2		*/
/*					_level=1: reconciliation _by1-_by2			*/
/*					_level=2: reconciliation top-_by2 (_by1='')	*/
/*		_LEAD:		number of month to forecast (std=12)		*/
/*		_BACK:		back option	(std=0)							*/
/*		_HOLDOUT:	houldout option (std=0)						*/
/*																*/
/* Output:	&_lib_out..&_file._HFC&_LEVEL						*/
/*																*/
/****************************************************************/
%macro Hierarchical_FC(_lib_in,_lib_out,_file,_var,_date,_by1,_by2,_HORIZON,_LEVEL=0,_lead=12,_back=0,_holdout=0);

data forecast;
	set &_lib_in..&_file;
	keep &_by1 &_by2 &_var &_date;
run;
proc casutil;
	droptable casdata="forecast";
	load data=forecast outcaslib="casuser"
	casout="forecast"  promote;
run;

*request ODS output outInfo and name it as hf_outInformation;
/* ods output OutInfo = hf_outInformation; */
%if &_LEVEL eq 0 %then %do;
	proc tsmodel data = casuser.forecast logcontrol= (error = keep warning = keep) 
		outSum = casuser.L0_outSum_HFC  outlog = casuser.L0_outLog_HFC  
		outobj = ( outEST = casuser.L0_outEst_HFC  outFor = casuser.L0_outFor_HFC  
			outStat = casuser.L0_outStat_HFC  outFmsg = casuser.L0_outFmsg_HFC  
			outSelect = casuser.L0_outSelect_HFC  outModelInfo = casuser.L0_outModelInfo_HFC  ) 
		errorstop = YES ;
		id  &_date interval = MONTH setmissing = MISSING trimid = LEFT;
		var  &_var/ acc =TOTAL setmiss =MISSING;
		
		require atsm;
		submit;
			declare object dataFrame(tsdf);
			declare object diagnose(diagnose);
			declare object diagSpec(diagspec);
			declare object inselect(selspec);
			declare object forecast(foreng);
			rc = dataFrame.initialize();
			rc = dataFrame.addY( &_var);
			rc = diagSpec.open();
			rc = diagSpec.setESM('METHOD', 'BEST');
			rc = diagSpec.setARIMAX('IDENTIFY', 'BOTH');
			rc = diagSpec.setIDM('INTERMITTENT', 10000);
			rc = diagSpec.setOption('CRITERION', "MAPE");
			rc = diagSpec.close();
			rc = diagnose.initialize(dataFrame);
			rc = diagnose.setSpec(diagSpec);
			rc = diagnose.setOption('BACK', &_BACK);
			rc = diagnose.setOption('minobs.trend',2);
			rc = diagnose.setOption('minobs.season',2);
			rc = diagnose.Run();
			ndiag = diagnose.nmodels();
			declare object COMBINED(combSpec);
			rc = COMBINED.open(ndiag);
			rc = COMBINED.AddFrom(diagnose);
			rc = COMBINED.close();
			rc = inselect.Open(ndiag);
			rc = inselect.AddFrom(diagnose);
			rc = inselect.close();
			
			rc = forecast.Initialize(dataFrame);
			rc = forecast.setOption('minobs.trend',2);
			rc = forecast.setOption('minobs.season',2);
			rc = forecast.setOption('minobs.mean',2);
			rc = forecast.setOption('HORIZON', "&_HORIZON"d);
			rc = forecast.setOption('LEAD',  &_LEAD);
			rc = forecast.setOption('BACK', &_BACK);
			rc = forecast.setOption('fcst.bd.lower',0);
			rc = forecast.setOption('HOLDOUT', &_HOLDOUT);
			rc = forecast.setOption('HOLDOUTPCT', 0);
			rc = forecast.setOption('CRITERION', "MAPE");
			
			rc = forecast.AddFrom(inselect);
			rc = forecast.AddFrom(COMBINED);
			rc = forecast.Run();
			declare object outEst(outEst);
			declare object outFor(outFor);
			declare object outStat(outStat);
			declare object outFmsg(outFmsg);
			declare object outSelect(outSelect);
			declare object outModelInfo(outModelInfo);
			rc = outEst.collect(forecast);
			rc = outFor.collect(forecast);
			rc = outStat.collect(forecast);
			rc = outFmsg.collect(forecast);
			rc = outSelect.collect(forecast);
			rc = outModelInfo.collect(forecast);
			
		endsubmit;
	run;
	quit;
%end;

*request ODS output outInfo and name it as hf_outInformation;
/* ods output OutInfo = hf_outInformation; */
proc tsmodel data = casuser.forecast logcontrol= (error = keep warning = keep) 
	outSum = casuser.L1_outSum_HFC  outlog = casuser.L1_outLog_HFC  
	outobj = ( outEST = casuser.L1_outEst_HFC  outFor = casuser.L1_outFor_HFC  
		outStat = casuser.L1_outStat_HFC  outFmsg = casuser.L1_outFmsg_HFC  
		outSelect = casuser.L1_outSelect_HFC  outModelInfo = casuser.L1_outModelInfo_HFC  ) 
	errorstop = YES ;
	id  &_date interval = MONTH setmissing = MISSING trimid = LEFT;
	var  &_var/ acc =TOTAL setmiss =MISSING;
	
	%if "&_by1" ne "" %then %do;
		by &_by1;
	%end;
	
	require atsm;
	submit;
		declare object dataFrame(tsdf);
		declare object diagnose(diagnose);
		declare object diagSpec(diagspec);
		declare object inselect(selspec);
		declare object forecast(foreng);
		rc = dataFrame.initialize();
		rc = dataFrame.addY( &_var);
		rc = diagSpec.open();
		rc = diagSpec.setESM('METHOD', 'BEST');
		rc = diagSpec.setARIMAX('IDENTIFY', 'BOTH');
		rc = diagSpec.setIDM('INTERMITTENT', 10000);
		rc = diagSpec.setOption('CRITERION', "MAPE");
		rc = diagSpec.close();
		rc = diagnose.initialize(dataFrame);
		rc = diagnose.setSpec(diagSpec);
		rc = diagnose.setOption('BACK', &_BACK);
		rc = diagnose.setOption('minobs.trend',2);
		rc = diagnose.setOption('minobs.season',2);
		rc = diagnose.Run();
		ndiag = diagnose.nmodels();
		declare object COMBINED(combSpec);
		rc = COMBINED.open(ndiag);
		rc = COMBINED.AddFrom(diagnose);
		rc = COMBINED.close();
		rc = inselect.Open(ndiag);
		rc = inselect.AddFrom(diagnose);
		rc = inselect.close();
		
		rc = forecast.Initialize(dataFrame);
		rc = forecast.setOption('minobs.trend',2);
		rc = forecast.setOption('minobs.season',2);
		rc = forecast.setOption('minobs.mean',2);
		rc = forecast.setOption('HORIZON', "&_HORIZON"d);
		rc = forecast.setOption('LEAD',  &_LEAD);
		rc = forecast.setOption('BACK', &_BACK);
		rc = forecast.setOption('fcst.bd.lower',0);
		rc = forecast.setOption('HOLDOUT', &_HOLDOUT);
		rc = forecast.setOption('HOLDOUTPCT', 0);
		rc = forecast.setOption('CRITERION', "MAPE");
		
		rc = forecast.AddFrom(inselect);
		rc = forecast.AddFrom(COMBINED);
		rc = forecast.Run();
		declare object outEst(outEst);
		declare object outFor(outFor);
		declare object outStat(outStat);
		declare object outFmsg(outFmsg);
		declare object outSelect(outSelect);
		declare object outModelInfo(outModelInfo);
		rc = outEst.collect(forecast);
		rc = outFor.collect(forecast);
		rc = outStat.collect(forecast);
		rc = outFmsg.collect(forecast);
		rc = outSelect.collect(forecast);
		rc = outModelInfo.collect(forecast);
		
	endsubmit;
run;
quit;

*request ODS output outInfo and name it as hf_outInformation;
/* ods output OutInfo = hf_outInformation; */
proc tsmodel data = casuser.forecast logcontrol= (error = keep warning = keep) 
	outSum = casuser.L2_outSum_HFC  
	outlog = casuser.L2_outLog_HFC  
	outobj = ( outEST = casuser.L2_outEst_HFC  
		outFor = casuser.L2_outFor_HFC  
		outStat = casuser.L2_outStat_HFC  
		outFmsg = casuser.L2_outFmsg_HFC  
		outSelect = casuser.L2_outSelect_HFC  
		outModelInfo = casuser.L2_outModelInfo_HFC  ) 
	errorstop = YES ;
	
	id  &_date interval = MONTH setmissing = MISSING trimid = LEFT;
	var  &_var/ acc =TOTAL setmiss =MISSING;
	
	by &_by1 &_by2;
	
	require atsm;
	submit;
		declare object dataFrame(tsdf);
		declare object diagnose(diagnose);
		declare object diagSpec(diagspec);
		declare object inselect(selspec);
		declare object forecast(foreng);
		rc = dataFrame.initialize();
		rc = dataFrame.addY( &_var);
		rc = diagSpec.open();
		rc = diagSpec.setESM('METHOD', 'BEST');
		rc = diagSpec.setARIMAX('IDENTIFY', 'BOTH');
		rc = diagSpec.setIDM('INTERMITTENT', 10000);
		rc = diagSpec.setUCM();
		rc = diagSpec.setOption('CRITERION', "MAPE");
		rc = diagSpec.close();
		rc = diagnose.initialize(dataFrame);
		rc = diagnose.setSpec(diagSpec);
		rc = diagnose.setOption('BACK', &_BACK);
		rc = diagnose.setOption('minobs.trend',2);
		rc = diagnose.setOption('minobs.season',2);
		rc = diagnose.Run();
		ndiag = diagnose.nmodels();
		declare object COMBINED(combSpec);
		rc = COMBINED.open(ndiag);
		rc = COMBINED.AddFrom(diagnose);
		rc = COMBINED.close();
		rc = inselect.Open(ndiag);
		rc = inselect.AddFrom(diagnose);
		rc = inselect.close();
		;
		rc = forecast.Initialize(dataFrame);
		rc = forecast.setOption('minobs.trend',2);
		rc = forecast.setOption('minobs.season',2);
		rc = forecast.setOption('minobs.mean',2);
		rc = forecast.setOption('HORIZON', "&_HORIZON"d);
		rc = forecast.setOption('LEAD',  &_LEAD);
		rc = forecast.setOption('BACK', &_BACK);
		rc = forecast.setOption('fcst.bd.lower',0);
		rc = forecast.setOption('HOLDOUT', &_HOLDOUT);
		rc = forecast.setOption('HOLDOUTPCT', 0);
		rc = forecast.setOption('CRITERION', "MAPE");
		
		rc = forecast.AddFrom(inselect);
		rc = forecast.AddFrom(COMBINED);
		rc = forecast.Run();
		declare object outEst(outEst);
		declare object outFor(outFor);
		declare object outStat(outStat);
		declare object outFmsg(outFmsg);
		declare object outSelect(outSelect);
		declare object outModelInfo(outModelInfo);
		rc = outEst.collect(forecast);
		rc = outFor.collect(forecast);
		rc = outStat.collect(forecast);
		rc = outFmsg.collect(forecast);
		rc = outSelect.collect(forecast);
		rc = outModelInfo.collect(forecast);

	endsubmit;
run;
quit;

%if &_LEVEL eq 0 %then %do;
	data casuser.L0_recfor_HFC;
		set casuser.L0_outfor_HFC ;
		if missing(PREDICT) then PREDICT = ACTUAL;
	run;
	
	proc tsreconcile child = casuser.L1_outfor_HFC  
		parent = casuser.L0_recfor_HFC  
		outfor = casuser.L1_recfor_HFC  
		aggregate = SUM sign = NONNEGATIVE ;
		by &_by1;
		id  &_date;
	run;
%end;

proc tsreconcile child = casuser.L2_outfor_HFC  
	%if &_LEVEL eq 0 %then %do;
		parent = casuser.L1_recfor_HFC  
	%end;
	%else %do;
		parent = casuser.L1_outfor_HFC  
	%end;	
	outfor = casuser.L2_recfor_HFC  
	aggregate = SUM sign = NONNEGATIVE ;
	by &_by1 &_by2;
	id  &_date;
run;

proc tsmodel data = casuser.L2_recfor_HFC  outobj = ( utlStat = casuser.L2_recStat_HFC  );
	id  &_date interval = MONTH;
	by &_by1 &_by2;
	var actual predict;
	require utl;
	submit;
	_STATNOBS = dim(actual) - &_LEAD;
	array _statACTUAL[1]/NOSYMBOLS;
	call dynamic_array(_statACTUAL, _STATNOBS);
	array _statPRED[1]/NOSYMBOLS;
	call dynamic_array(_statPRED, _STATNOBS);
	do i = 1 to _STATNOBS;
	_statACTUAL[i] = actual[i];
	_statPRED[i] = predict[i];
	end;
	declare object utlStat(utlStat);
	rc = utlStat.collect(_statACTUAL, _statPRED, 0, 0);
	endsubmit;
run;

data casuser.L2_recStat_HFC  ;
	merge casuser.L2_recStat_HFC  casuser.L2_outStat_HFC (keep=&_by1 &_by2 _REGION_ _NAME_ _MODEL_);
	by &_by1 &_by2 _REGION_;
run;

data &_lib_out..&_file._HFC&_LEVEL;
	set CASUSER.L2_outFor_HFC (datalimit=99999999999);
	if predict ne .;
run;

proc sort data=&_lib_out..&_file._HFC&_LEVEL ;
	by &_by1 &_by2 &_date;
run;


data &_lib_out..&_file._rec_HFC&_LEVEL;
	set CASUSER.L2_recfor_HFC (datalimit=99999999999);
	if predict ne .;
run;

proc sort data=&_lib_out..&_file._rec_HFC&_LEVEL ;
	by &_by1 &_by2 &_date;
run;

data &_lib_out..Model_info_&_file._HFC&_LEVEL;
	set CASUSER.L2_outModelInfo_HFC (datalimit=99999999999);
run;

%mend Hierarchical_FC;

/*************************************/
%Hierarchical_FC(Data_IN,Data_OUT,SEG_Long_A,A,date,BU,FC_var,01JUL2019,_LEVEL=1,_lead=6,_holdout=3);
/*************************************/

/* ods exclude all; */
