*options source source2 mprint mlogic;

/****************************************************************/
/* Modul Auto_FC: 												*/
/*		Auto-Forcasting using ESM, ARIMA and UCM models			*/
/*																*/
/* Input:														*/
/* 		_LIB_IN: 	Data input library							*/
/* 		_LIB_OUT: 	Data output library							*/
/*		_FILE:		Data File 									*/
/*		_VAR:		Variable to forecast						*/
/*		_DATE:		Time Variable (interval=MONTH) 				*/
/*		_BY:		Segment Variable							*/
/*		_HORIZON:	first Forecast Month						*/
/*		_LEAD:		number of Month to forecast (std=12)		*/
/*		_BACK:		Back Option	(std=0)							*/
/*		_HOLDOUT:	Houldout Option (std=0)						*/
/*																*/
/* Output:	&_lib_out..&_file._AFC								*/
/*																*/
/* Author: Franz Helmreich, 				Date: 25.July 2019	*/
/*																*/
/****************************************************************/
%macro Auto_FC(_lib_in,_lib_out,_file,_var,_date,_by,_HORIZON,_lead=12,_back=0,_holdout=0);


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
*request ODS output outInfo and name it as hf_outInformation;

/* ods output OutInfo = hf_outInformation; */
proc tsmodel data = casuser.forecast logcontrol= (error = keep warning = keep) 
			outSum = casuser.outSum_AFC 
			outlog = casuser.outLog_AFC 
			outobj = ( 	outEST = casuser.outEst_AFC 
						outFor = casuser.outFor_AFC 
						outStat = casuser.outStat_AFC 
						outFmsg = casuser.outFmsg_AFC 
						outSelect = casuser.outSelect_AFC 
						outModelInfo = casuser.outModelInfo_AFC ) 
			errorstop = YES ;
			
id &_date interval = MONTH setmissing = MISSING trimid = LEFT;
var &_var/ acc =TOTAL setmiss =MISSING;

by &_by;

require atsm;
submit;
declare object dataFrame(tsdf);
declare object diagnose(diagnose);
declare object diagSpec(diagspec);
declare object inselect(selspec);
declare object forecast(foreng);
rc = dataFrame.initialize();
rc = dataFrame.addY(&_var);
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

rc = forecast.Initialize(dataFrame);
rc = forecast.setOption('minobs.trend',2);
rc = forecast.setOption('minobs.season',2);
rc = forecast.setOption('minobs.mean',2);
rc = forecast.setOption('HORIZON', "&_HORIZON"d);
rc = forecast.setOption('LEAD', &_lead);
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


/* data CASUSER.auto_info_seg_&_file.; */
/* 	set work.sforecast_outInformation; */
/* run; */

data &_lib_out..&_file._AFC;
	set CASUSER.outfor_AFC (datalimit=99999999999);
	if predict ne .;
run;

proc sort data=&_lib_out..&_file._AFC ;
	by &_by &_date;
run;


data &_lib_out..Model_info_&_file._AFC;
	set CASUSER.OUTMODELINFO_AFC (datalimit=99999999999);
run;

%mend Auto_FC;

/*************************************/
%Auto_FC(Data_IN,Data_OUT,SEG_Long_A,A,date,FC_var,01JUL2019,_lead=6,_holdout=3);
/*************************************/

ods exclude all;
