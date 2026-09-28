*options source source2 mprint mlogic;

ods noproctitle;
ods graphics / imagemap=on;

%macro UCM_FC(_lib_in,_file,_var,_date,_by,_type,_lead=12,_back=0);

	data _null_;
		IL=scan("&_type",2,'_');
		I=substr(IL,1,1);
		L=substr(IL,2,1);
		call symput('_irregular',I);
		call symput('_level',L);
	run;
	
/* 	data forecast; */
/* 		set &_lib_in..&_file; */
/* 		keep &_by &_var &_date; */
/* 	run; */
	proc casutil;
		droptable casdata="forecast";
		load data=&_lib_in..&_file outcaslib="casuser"
		casout="forecast"  promote;
	run;
		
	proc tsmodel data=CASUSER.forecast outobj=(outFcast=CASUSER.forecast_out) seasonality=12;
	
		id date interval=MONTH FORMAT=_DATA_;
		var &_var;
		by &_by;
		
		require tsm;
		submit;
		array ar[1]/nosymbols;
		array ma[1]/nosymbols;
		declare object myModel(TSM);
		declare object mySpec(UCMSpec);
		rc=mySpec.Open();
		%if "&_irregular" eq '1' %then %do;
			rc=mySpec.AddComponent('irregular');
		%end;
		%if "&_level" eq '1' %then %do;
			rc=mySpec.AddComponent('level');
		%end;
		rc=mySpec.Close();
	
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
	
%mend UCM_FC;

/************************************************
%UCM_FC(Data_IN,SEG_LONG_A,A,date,FC_var,UCM_00,_lead=6);
%UCM_FC(Data_IN,SEG_short_A,A,date,FC_var,UCM_11,_lead=6);
/************************************************/

