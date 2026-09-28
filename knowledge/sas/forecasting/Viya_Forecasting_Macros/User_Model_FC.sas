*options source source2 mprint mlogic;

/****************************************************************/
/* Modul: Auto-Forcasting based on user defined 				*/
/* 		  model selection list									*/
/*																*/
/* Model selection list (userdefined): 							*/
/*		XLSX-File (in macro _model_list)						*/
/*																*/
/* Input:														*/
/* 		_LIB_IN: 	Data input library							*/
/* 		_LIB_OUT: 	Data output library							*/
/*		_FILE:		file to foreast								*/
/*		_VAR:		forecast variable							*/
/*		_DATE:		time variable (interval=MONTH) 				*/
/*		_BY:		segment variable							*/
/*		_first_FC:	first forecast month						*/
/*		_LEAD:		number of month to forecast (std=12)		*/
/*		_HOLDOUT:	houldout option (std=0)						*/
/*																*/
/* Output:	_lib_out._file										*/
/*			&_lib_out..Model_info_file							*/
/*																*/
/****************************************************************/
%macro User_Model_FC(_lib_in,_lib_out,_file,_var,_date,_by,_first_FC,_lead=12,_holdout=0);
	
	PROC IMPORT
	        DATAFILE="/opt/data/HPF-Engine/EXCEL/&_model_list..xlsx"
	        OUT=WORK.Model_list
	        REPLACE
	        DBMS=xlsx;
	    sheet="Sheet1";
	    GETNAMES=YES;
	RUN;
	
	%let _nr_ESM=0;
	%let _nr_ARIMA=0;
	%let _nr_UCM=0;

	data _null_;
		set Model_list end=ende;
		retain esm 0 arima 0 UCM 0;
		if model ne '' then do;
			if Model =: 'ARIMA' then do;
				arima+1;
				call symput('_arima'!!left(arima),trim(model));
			end;
			else if Model =: 'UCM' then do;
				UCM+1;
				call symput('_UCM'!!left(UCM),trim(model));
			end;
			else do;
				esm+1;
				call symput('_esm'!!left(esm),Model);
			end;
		end;
		if ende then do;
			call symput('_nr_ESM',esm);
			call symput('_nr_ARIMA',arima);
			call symput('_nr_UCM',UCM);
		end;  
	run;
	%put ***List of User Models   *** &_model_list=;
	%put ***Number of ESM-Models  *** &_nr_ESM=;
	%put ***Number of ARIMA-Models*** &_nr_ARIMA=;
	%put ***Number of UCM-Models  *** &_nr_UCM=;

	%include '/opt/data/HPF-Engine/Sourcen/Macro_ARIMA.sas';
	%include '/opt/data/HPF-Engine/Sourcen/Macro_ESM.sas';
	%include '/opt/data/HPF-Engine/Sourcen/Macro_UCM.sas';

/***********************************************************/
/*** start model selection *********************************/
/***********************************************************/
	data forecast_err;
		format Model_name $15. error 8. &_by. $50. &_date date9.;;
	run;
	%do kkk = 1 %to &_nr_ESM;
		title "Modell=&&_esm&kkk";
		%ESM_FC(&_lib_in.,&_file.,&_var,&_date,&_by.,&&_esm&kkk,_lead=&_holdout,_back=&_holdout);
		data forecast_out;
			set casuser.forecast_out (datalimit=99999999999);
			Model_name=upcase("&&_esm&kkk");	
		run;
		proc sort data=forecast_out;
			by &_by. &_date;
		run;
		data forecast_out;
			merge forecast_out &_lib_in..&_file. (keep=&_var &_by. &_date);
			by &_by. &_date;
			error=abs(&_var - predict);		
		run;
		proc append base=forecast_err new=forecast_out force;
		run;
	%end;

	%do kkk = 1 %to &_nr_UCM;
		title "Modell=&&_ucm&kkk";
		%UCM_FC(&_lib_in.,&_file.,&_var,&_date,&_by.,&&_ucm&kkk,_lead=&_holdout,_back=&_holdout);
		data forecast_out;
			set casuser.forecast_out (datalimit=99999999999);
			Model_name=upcase("&&_ucm&kkk");	
		run;
		proc sort data=forecast_out;
			by &_by. &_date;
		run;
		data forecast_out;
			merge forecast_out &_lib_in..&_file. (keep=&_var &_by. &_date);
			by &_by. &_date;
			error=abs(&_var - predict);		
		run;
		proc append base=forecast_err new=forecast_out force;
		run;
	%end;

	%do kkk = 1 %to &_nr_ARIMA;
		title "Modell=&&_arima&kkk";
		%ARIMA_FC(&_lib_in.,&_file.,&_var,&_date,&_by.,&&_arima&kkk,_lead=&_holdout,_back=&_holdout);
		data forecast_out;
			set casuser.forecast_out (datalimit=99999999999);
			Model_name=upcase("&&_arima&kkk") ;	
		run;
		proc sort data=forecast_out;
			by &_by. &_date;
		run;
		data forecast_out;
			merge forecast_out &_lib_in..&_file. (keep=&_var &_by. &_date);
			by &_by. &_date;
			error=abs(&_var - predict);		
		run;
		proc append base=forecast_err new=forecast_out force;
		run;
	%end;

	data _null_;
		datum="&_first_FC"d;
		format holdout_start holdout_end last_FC date9.;
		holdout_start=intnx('month',datum,-&_holdout,'same');	
		holdout_end=intnx('month',datum,-1,'same');
		last_FC=intnx('month',datum,&_lead-1,'same');
		call symput('_holdout_start',put(holdout_start,date9.));
		call symput('_holdout_end',put(holdout_end,date9.));
		call symput('_last_FC',put(last_FC,date9.));
	run;
	%put ***Timestamps*** &_holdout_start= &_holdout_end= &_first_FC= &_last_FC=;
		
	proc sort data=forecast_err;
		by &_by. Model_name;
		where error ne .;
	run;
	data fehler;
		set forecast_err;
		if &_date. ge "&_holdout_start"d and &_date. le "&_holdout_end"d;
		error=abs(error);
	run;	
	proc freq data=fehler;
		table Model_name;
		title 'fehler';
	run;

	proc summary data=fehler nway;
		by &_by. Model_name;
		var error;
		output out=&_lib_out..Model_info_&_file. (drop=_freq_ _type_) sum=;
	run;
	proc sort data=&_lib_out..Model_info_&_file.;
		by &_by. error;
	run;
	proc sort data=&_lib_out..Model_info_&_file. nodupkey;
		by &_by.;
	run;
	proc freq data=&_lib_out..Model_info_&_file.;
		table Model_name;
		title "&_lib_out..Model_info_&_file.";
	run;
	
	proc sort data=&_lib_out..Model_info_&_file. out=model_types nodupkey;
		by Model_name;
	run;
	
/***********************************************************/
/*** start forecasting *************************************/
/***********************************************************/
	data null;
		set model_types end=ende;
		format type $5.;
		call symput('_seg_mod'!!left(_N_),trim(Model_name));
		if Model_name =: 'ARIMA' or Model_name =: 'UCM' then 
			type=scan(Model_name,1,'_');
		else type='ESM';
		call symput('_seg_type'!!left(_N_),trim(type));
		
		if ende then call symput('_nr_model',_N_);
	run;

	data &_lib_out..&_file;
		set CASUSER.forecast_out (obs=0);
		drop error  _name_;
	run;

	%do kkk = 1 %to &_nr_model;
		%put ***Forecast Model*** &&_seg_mod&kkk= &&_seg_type&kkk=;
		data error_seg;
			set &_lib_out..Model_info_&_file.;
			where Model_name eq "&&_seg_mod&kkk";
			keep &_by. Model_name;
		run;
		proc sort data=&_lib_in..&_file.;
			by &_by. &_date.;
		run;
		data forecast_seg;
			merge &_lib_in..&_file. error_seg (In=in2);
			by &_by.;
			if in2;
		run;
		
		title "Modell=&&_seg_mod&kkk";

		%if "&&_seg_type&kkk" eq "ARIMA" %then %do;
			%ARIMA_FC(work,forecast_seg,&_var,&_date,&_by.,&&_seg_mod&kkk,_lead=&_lead,_back=0);
		%end;
		%if "&&_seg_type&kkk" eq "UCM" %then %do;
			%UCM_FC(work,forecast_seg,&_var,&_date,&_by.,&&_seg_mod&kkk,_lead=&_lead,_back=0);
		%end;
		%if "&&_seg_type&kkk" eq "ESM" %then %do;
			%ESM_FC(work,forecast_seg,&_var,&_date,&_by.,&&_seg_mod&kkk,_lead=&_lead,_back=0);
		%end;
		
		data forecast_cas;
			set casuser.forecast_out (datalimit=99999999999);
/* 			Model_name=upcase("&&_esm&kkk");	 */
		run;
		proc append base=&_lib_out..&_file new=forecast_cas force;
		run;
	%end;
	proc sort data=&_lib_out..&_file.;
		by &_by. &_date.;
	run;
	data &_lib_out..&_file;
		length model_name $15.;
		merge &_lib_out..&_file &_lib_out..Model_info_&_file. (In=in2);
		by &_by.;
/* 		if &_date. ge "&_first_FC"d and &_date. le "&_last_FC"d; */
		if predict ne .;
	run;
%mend User_Model_FC;

/*************************************
%let _model_list=Modelle_short;
%User_Model_FC(DATA_in,DATA_OUT,SEG_short_A,A,date,FC_var,01JUL2019,_lead=6,_holdout=1);

%let _model_list=Modelle_long;
%User_Model_FC(DATA_in,DATA_OUT,SEG_long_A,A,date,FC_var,01JUL2019,_lead=6,_holdout=3);
*************************************/
/*************************************/
/* %let _model_list=Modelle_single_ESM; */
/* %User_Model_FC(DATA_in,DATA_OUT,long_a_esm,A,date,FC_var,01JUL2019,_lead=6,_holdout=6); */

/* %let _model_list=Modelle_single_ARIMA; */
/* %User_Model_FC(DATA_in,DATA_OUT,long_a_arima,A,date,FC_var,01JUL2019,_lead=6,_holdout=6); */

/* %let _model_list=Modelle_single_UCM; */
/* %User_Model_FC(DATA_in,DATA_OUT,long_a_ucm,A,date,FC_var,01JUL2019,_lead=6,_holdout=6); */
*************************************/
