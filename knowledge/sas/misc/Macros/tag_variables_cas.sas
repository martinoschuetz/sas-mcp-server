/*options mprint;
cas mySession2 sessopts=(caslib=casuser timeout=1800 locale="en_US");
caslib _all_ assign;

proc casutil;
	load data=sashelp.class outcaslib="casuser" casout="class";
run;

data casuser.class2;
	set casuser.class;

	if strip(name) eq 'Philip' then
		age = 27;
run;

*/
/* 	Automatically performs percentile tagging for the desired variables */

/*	vars = list of variables to be tagged separated by blank. Minimum one value.
percentiles = list of percentiles to be computed. Minimum one value.
*/
%macro tag_variable_cas(incaslib=, inds=, outcaslib=, outds=, vars=, percentiles=);
	%local i j var perc;
	%put Vars=%str(&vars.);
	%let NVars=%sysfunc(countw(%str(&vars.)));
	%put &=NVars.;
	%put Percentiles=%str(&percentiles.);
	%let NPercs=%sysfunc(countw(%str(&Percentiles.)));
	%put &=NPercs.;
	%let var=%scan(&vars., 1);
	%put I=1 &=var.;
	%let perc=%scan(&Percentiles., 1);
	%put J=1 &=perc.;
	ods exclude all;

	proc cas;
		percentile.percentile /     
			table={caslib="&incaslib.", name="&inds.", 
			vars={"&var."

			%do i=2 %to &NVars.;
				%let var=%scan(&vars., &i.);
				%put VAR: &=i. &=var.;
				, "&var."
			%end;

		}},
		casOut={caslib="casuser", name="percentiles", replace=TRUE},
		values={&perc.
			%do j=2 %to &NPercs.;
				%let perc=%scan(&Percentiles., &j.);
				%put PERC: &=j. &=perc.;
				, &perc.
			%end;
		};
	quit;

	ods exclude none;

	proc sql noprint;
		select sum(_converged_) into :no_converged from casuser.percentiles;
	quit;

	%put NOTE: &no_converged estimates out of %sysevalf(&nvars. * &npercs.) converged.;

	proc transpose data=casuser.percentiles out=casuser.percentiles_t prefix=P_;
		by _Column_;
		var _value_;
		id _Pctl_;
	run;

	%do i = 1 %to &nvars.;
		%let var=%scan(&vars., &i.);

		data _null_;
			set casuser.percentiles_t(where=(_Column_ eq "&var.") obs=1);

			%do j=1 %to &npercs.;
				%let perc=%scan(&Percentiles., &j.);
				call symput("&var._P_&perc.",P_&perc.);
			%end;
		run;

	%end;

	%do i = 1 %to &nvars.;
		%let var=%scan(&vars., &i.);

		%do j=1 %to &npercs.;
			%let perc=%scan(&Percentiles., &j.);
			%put &var._P_&perc. = &&&var._P_&perc..;
		%end;
	%end;

	data &outcaslib..&outds.;
		set &incaslib..&inds.;

		%do i = 1 %to &nvars.;
			%let var=%scan(&vars., &i.);

			%do j=1 %to &npercs.;
				%let perc=%scan(&Percentiles., &j.);

				%if %sysevalf(&perc. < 50) %then
					%do;
						/*%put UNDER 0.5;*/
						&var._P_&perc.=ifn(&var. < &&&var._P_&perc.., 1, 0);
					%end;
				%else
					%do;
						/*%put ABOVE 0.5;*/
						&var._P_&perc.=ifn(&var. > &&&var._P_&perc.., 1, 0);
					%end;
			%end;
		%end;
	run;

	proc delete data=casuser.percentiles;
	run;

	proc delete data=casuser.percentiles_t;
	run;

%mend tag_variable_cas;

*%tag_variable_cas(incaslib=casuser, inds=class2, outcaslib=casuser, outds=class_tagged, vars=Age Height Weight, percentiles=1 5 95 99);

*cas mySession2 terminate;