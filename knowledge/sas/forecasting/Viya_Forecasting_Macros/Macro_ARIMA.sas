*options source source2 mprint mlogic;

ods noproctitle;
ods graphics / imagemap=on;

%macro ARIMA_FC(_lib_in,_file,_var,_date,_by,_type,_lead=12,_back=0);

	data _null_;
		format PDQ $3.  xNOINT $5.;
		PDQ=scan("&_type",2,'_');
		P=substr(PDQ,1,1);
		D=substr(PDQ,2,1);
		Q=substr(PDQ,3,1);
		xNOINT=scan("&_type",3,'_');
		if upcase(xNOINT) eq 'NOINT' then noint='1';
		else noint='0';
		call symput('_P',P);
		call symput('_D',D);
		call symput('_Q',Q);
		call symput('_NOINT',noint);
	run;
	%put ***ARIMA Parameter*** &_P= &_D= &_Q= &_NOINT=;
	
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
		id &_date interval=MONTH FORMAT=_DATA_;
		var &_var.;
		by &_by.;
		require tsm;
		submit;
		%if &_D gt 0 %then %do;
			array diff[&_D]/nosymbols;
		%end;
		array ar[1]/nosymbols;
		array ma[1]/nosymbols;
	
		declare object myModel(TSM);
		declare object mySpec(ARIMASpec);
		rc=mySpec.Open();
	
		/* Specify differencing orders */
		%if &_D gt 0 %then %do;
			%do iii = 1 %to  &_D;
				diff[&iii]=1;
			%end;
			rc=mySpec.SetDiff(diff);
		%end;
	
		/* Specify AR orders. For example: p = (1)(12) */
		%if &_P gt 0 %then %do;
			%do iii = 1 %to  &_P;
				ar[1]=&iii;
				rc=mySpec.AddARPoly(ar);
			%end;
		%end;
	
		/* Specify MA orders. For example: q = (1)(12) */
		%if &_Q gt 0 %then %do;
			%do iii = 1 %to  &_Q;
				ma[1]=&iii;
				rc=mySpec.AddMAPoly(ma);
			%end;
		%end;
		
		%if "&_NOINT" eq "1" %then %do;
			rc=mySpec.SetOption('noint', 1);
		%end;
		rc=mySpec.SetOption('method', 'ML');
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
%mend ARIMA_FC;

/****************************************
%ARIMA_FC(Data_IN,SEG_SHORT_A,A,date,FC_var,ARIMA_000,_lead=6);

/****************************************/

