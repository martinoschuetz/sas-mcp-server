/* 	Count number of variables for data set.
	Value returned in global macro variable nocols */
%macro no_cols(ds=);
	%global nocols;
	%let dsid=%sysfunc(open(&ds.));
	%let nvar=%sysfunc(attrn(&dsid.,nvar));
	%let dsid=%sysfunc(close(&dsid.));
	%let nocols= &nvar.;
	/*%put &ds.: &nocols.;*/
%mend;
/*
%no_cols(ds=sashelp.class);
%put &=nocols;
*/