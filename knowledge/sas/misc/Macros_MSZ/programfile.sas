/* Copyright (c) 2024 by SAS Institute Inc., Cary, NC USA 27513 */

/* Identify the path to a file */
%macro programfile;
	%local viyaHost;
	
	%if %symexist(SYS_JES_JOB_URI) %then %do;

		filename out temp;

		%let viyaHost=%sysfunc(getoption(SERVICESBASEURL));
		proc http url="&viyaHost.&SYS_JES_JOB_URI."
			method='get'
			out=out
			oauth_bearer = sas_services;
			headers 'Accept'='application/json';
		run;

/*		%put NOTE: &viyaHost.&SYS_JES_JOB_URI.;*/

		libname out json;
		
		proc sql noprint;
			select value into :_SASPROGRAMFILE from out.jobdefinition_properties where name = "DeployedResourceName";
		quit;
			
/*		%put NOTE: SYS_JES_JOB_URI exists: &=_SASPROGRAMFILE.;*/

		libname out clear;
		filename out clear;
	%end;
	%else %do;
		%put NOTE: SYS_JES_JOB_URI DOES NOT exist: &=_SASPROGRAMFILE.;
	%end;

	%let sas_filename=%scan(&_SASPROGRAMFILE.,-1,"/");
/*	%put NOTE: SAS filename = &sas_filename.;*/

	%let INSTALLDIRECTORY=%sysfunc(tranwrd(&_SASPROGRAMFILE.,/&sas_filename.,));
/*	%put NOTE: &=INSTALLDIRECTORY.;*/

%mend programfile;

/* %programfile; */
