*options source source2 mprint mlogic;

ods noproctitle;
ods graphics / imagemap=on;
/****************************************
_type=linear, simple, damptrend, seasonal, multseasonal, winters  and addwinters 
****************************************/

%macro ESM_FC(_lib_in,_file,_var,_date,_by,_type,_lead=12,_back=0);

/* data forecast; */
/* 	set &_lib_in..&_file; */
/* 	keep &_by &_var &_date; */
/* run; */
proc casutil;
	droptable casdata="forecast";
	load data=&_lib_in..&_file outcaslib="casuser"
	casout="forecast"  promote;
run;

proc tsmodel data=CASUSER.forecast outobj=(outFcast=CASUSER.forecast_out) seasonality=12 ;
	id &_date interval=MONTH FORMAT=_DATA_;
	var &_var;
	by &_by;
	require tsm;
	submit;
	declare object myModel(TSM);
	declare object mySpec(ESMSpec);
	rc=mySpec.open();
	rc=mySpec.SetOption('method', "&_type");
	rc=mySpec.SetTransform('none', 'mean');
	rc=mySpec.close();

	/* Setup and run the TSM model object */
	rc=myModel.Initialize(mySpec);
	rc=myModel.SetY(&_var);
	rc=myModel.SetOption('lead', &_lead);
	rc=myModel.SetOption('back', &_back);
	rc=myModel.SetOption('alpha', 0.05);
	rc=myModel.Run();

	/* Output model forecasts and estimates */
	declare object outFcast(TSMFor);
	rc=outFcast.Collect(myModel);
	endsubmit;
run;

%mend ESM_FC;

/***************************************
%ESM_FC(DATA_IN,SEG_SHORT_A,A,DATE,FC_var,simple,_lead=6);

/**************************************/