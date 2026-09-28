*options source source2 mprint mlogic;

/****************************************************************/
/* Modul TSR_FC: Time Series Regression							*/
/*																*/
/* Input:														*/
/* 		_LIB_IN: 	Data input library							*/
/* 		_LIB_OUT: 	Data output library							*/
/*		_FILE:		Data File 									*/
/*		_VAR:		Variable to forecast						*/
/*		_DATE:		Time Variable (interval=MONTH) 				*/
/*		_BY:		Segment Variable							*/
/*		_HORIZON:	first Forecast Month						*/
/*		_NOINT:		avoiding Constant Term (std=1)				*/
/*		_LEAD:		number of Month to forecast (std=12)		*/
/*		_BACK:		Back Option	(std=0)							*/
/*		_HOLDOUT:	Houldout Option (std=0)						*/
/*																*/
/* Output:	&_lib_out..&_file._TSR&_NOINT						*/
/*																*/
/* Author: Franz Helmreich, 				Date: 25.July 2019	*/
/*																*/
/****************************************************************/
%macro TSR_FC(_lib_in,_lib_out,_file,_var,_date,_by,_HORIZON,_NOINT=1,_lead=12,_back=0,_holdout=0);

data forecast;
	set &_lib_in..&_file;
	keep &_by &_var &_date;
run;
proc casutil;
	droptable casdata="forecast";
	load data=forecast outcaslib="casuser"
	casout="forecast"  promote;
run;
	
*request ODS output outInfo and name it as sforecast_outInformation;
/* ods output OutInfo = vf_outInformation; */

proc tsmodel data = CASUSER.forecast logcontrol= (error = keep warning = keep) 
	outSum = CASUSER.outSum_TSR 
	outlog = CASUSER._outLog_TSR 
	outarray = CASUSER.outarray_TSR 
	outobj=( outEst = CASUSER.outEst_TSR 
			outFor = CASUSER.outFor_TSR 
			outStat= CASUSER.outStat_TSR 
			outFmsg = CASUSER.outFmsg_TSR 
			outSelect= CASUSER.outSelect_TSR 
			outModelInfo= CASUSER.outModelInfo_TSR ) 
			errorstop = YES ;
id &_date interval=MONTH setmissing=MISSING trimid=LEFT;
var &_var/ acc =TOTAL setmiss =MISSING;
;
;
by &_by ;
outarrays vf_t1 vf_t2 vf_t3 _seasonalDummy1 _seasonalDummy2 _seasonalDummy3 _seasonalDummy4 _seasonalDummy5 _seasonalDummy6 _seasonalDummy7 _seasonalDummy8 _seasonalDummy9 _seasonalDummy10 _seasonalDummy11 _seasonalDummy12;
require atsm;
submit;
do t=1 to _LENGTH_;
vf_t1[t] = _cycle_[t];
vf_t2[t] = _cycle_[t]**2;
vf_t3[t] = _cycle_[t]**3;
;
end;
subroutine seasonalDummies(timeID[*], seasonality, _seasonalDummy1[*], _seasonalDummy2[*], _seasonalDummy3[*], _seasonalDummy4[*], _seasonalDummy5[*], _seasonalDummy6[*], _seasonalDummy7[*], _seasonalDummy8[*], _seasonalDummy9[*], _seasonalDummy10[*], _seasonalDummy11[*], _seasonalDummy12[*]);
outargs _seasonalDummy1, _seasonalDummy2, _seasonalDummy3, _seasonalDummy4, _seasonalDummy5, _seasonalDummy6, _seasonalDummy7, _seasonalDummy8, _seasonalDummy9, _seasonalDummy10, _seasonalDummy11, _seasonalDummy12;
array _season[1] / NOSYMBOLS;
call dynamic_array(_season, dim(timeID));
do i = 1 to dim(timeID);
_season[i] = intindex('MONTH', timeID[i]);
_seasonalDummy1[i] = 0;
_seasonalDummy2[i] = 0;
_seasonalDummy3[i] = 0;
_seasonalDummy4[i] = 0;
_seasonalDummy5[i] = 0;
_seasonalDummy6[i] = 0;
_seasonalDummy7[i] = 0;
_seasonalDummy8[i] = 0;
_seasonalDummy9[i] = 0;
_seasonalDummy10[i] = 0;
_seasonalDummy11[i] = 0;
_seasonalDummy12[i] = 0;
;
if _season[i] = 1 then _seasonalDummy1[i] = 1;
else if _season[i] = 2 then _seasonalDummy2[i] = 1;
else if _season[i] = 3 then _seasonalDummy3[i] = 1;
else if _season[i] = 4 then _seasonalDummy4[i] = 1;
else if _season[i] = 5 then _seasonalDummy5[i] = 1;
else if _season[i] = 6 then _seasonalDummy6[i] = 1;
else if _season[i] = 7 then _seasonalDummy7[i] = 1;
else if _season[i] = 8 then _seasonalDummy8[i] = 1;
else if _season[i] = 9 then _seasonalDummy9[i] = 1;
else if _season[i] = 10 then _seasonalDummy10[i] = 1;
else if _season[i] = 11 then _seasonalDummy11[i] = 1;
else if _season[i] = 12 then _seasonalDummy12[i] = 1;
;
end;
endsub;
call seasonalDummies(&_date, 12, _seasonalDummy1, _seasonalDummy2, _seasonalDummy3, _seasonalDummy4, _seasonalDummy5, _seasonalDummy6, _seasonalDummy7, _seasonalDummy8, _seasonalDummy9, _seasonalDummy10, _seasonalDummy11, _seasonalDummy12);
;
array zero[2] /nosymbols;
zero[1]=0;
zero[2]=0;
declare object dataFrame(tsdf);
declare object diagnose(diagnose);
declare object diagspec(diagspec);
declare object inselect(selspec);
declare object forecast(foreng);
rc = dataFrame.initialize();
rc = dataFrame.addY(&_var);
rc = dataFrame.addX(vf_t1, 'required', 'NO');
rc = dataFrame.addX(vf_t2, 'required', 'NO');
rc = dataFrame.addX(vf_t3, 'required', 'NO');
rc = dataFrame.addX(_seasonalDummy1, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy2, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy3, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy4, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy5, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy6, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy7, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy8, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy9, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy10, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy11, 'required', 'YES');
rc = dataFrame.addX(_seasonalDummy12, 'required', 'YES');
rc = diagSpec.open();
rc = diagSpec.SetARIMAX('NOINT',&_NOINT,'P',zero,'Q',zero,'PS',zero,'QS',zero, 'XDEN', zero, 'XNUM', zero, 'ESTMETHOD', 'CLS', 'METHOD', 'ESACF', 'SIGLEVEL', constant('SMALL'));
rc = diagSpec.SetTrend('DIFF', 'none','SDIFF','none');
rc = diagSpec.SetOption('DELAYINPUT', 0, 'DELAYEVENT', 0, 'criterion', 'MAPE');
rc = diagSpec.Close();
rc = diagnose.initialize(dataFrame);
rc = diagnose.setSpec(diagSpec);
rc = diagnose.setOption('BACK', &_BACK);
rc = diagnose.setOption('HOLDOUT', &_HOLDOUT);
rc = diagnose.setOption('HOLDOUTPCT', 0);
rc = diagnose.setOption('CRITERION', "MAPE");
rc = diagnose.Run();
ndiag = diagnose.nmodels();
rc = inselect.Open(ndiag);
rc = inselect.AddFrom(diagnose);
rc = inselect.close();
;
rc = forecast.Initialize(dataFrame);
rc = forecast.setOption('HORIZON', "&_HORIZON"d);
rc = forecast.setOption('LEAD', &_lead);
rc = forecast.setOption('BACK', &_BACK);
rc = forecast.setOption('fcst.bd.lower',0);
rc = forecast.setOption('HOLDOUT', &_HOLDOUT);
rc = forecast.setOption('HOLDOUTPCT', 0);
rc = forecast.setOption('CRITERION', "MAPE");
;
rc = forecast.AddFrom(inselect);
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
;
endsubmit;
run;
quit;


data &_lib_out..&_file._TSR&_NOINT;
	set CASUSER.outFor_TSR (datalimit=99999999999);
	if predict ne .;
run;


proc sort data=&_lib_out..&_file._TSR&_NOINT ;
	by &_by &_date;
run;

data &_lib_out..Model_info_&_file._TSR&_NOINT;
	set CASUSER.OUTMODELINFO_TSR (datalimit=99999999999);
run;

%mend TSR_FC;

/*************************************/
%TSR_FC(Data_IN,Data_OUT,SEG_Long_A,A,date,FC_var,01JUL2019,_NOINT=1,_lead=6,_holdout=3);
/**************************************/
ods exclude all;
