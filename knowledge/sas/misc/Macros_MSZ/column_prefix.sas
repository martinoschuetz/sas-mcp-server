/* Copyright (c) 2022 by SAS Institute Inc., Cary, NC USA 27513 */

/*
options mprint;
%let DEBUG=TRUE;

data tmp;
	set sashelp.class;
	label Age="LAge";
	label Height="LHeight";
	label Name="LName";
	label Sex="LSex";
	label Weight="LWeight";
run;
*/
/* Don't use prefix with characters which are non conformant with SAS column naming conventions. */

%macro column_prefix(lib=, dsin=, prefix=, varcount=);
	%local i;
	%local n;

	proc contents data=&lib..&dsin. out=_out_ noprint; run;

	proc sort data=_out_;
		by varnum;
	run;

	proc sql noprint;
		select name into :names separated by '|' from _out_;
		select compress(label, ',;') into :labels separated by '|' from _out_;
	quit;

	%let N=&sqlobs.;
	%let n_global=&sqlobs.;
	%if &debug. eq TRUE %then %do;
		%put &=N.;
		%put &=names.;
		%put &=labels.;
	%end;

	%let rename_statement=;
	%let relabel_statement=;

	%do i=1 %to &N.;
		%let name = %scan(&names., &i., "|", M);
		%let lab = %scan(&labels., &i., "|", M);
		%if &debug eq TRUE %then %do;
			%put &=i. &=name.;
			%put &=i. &=lab.;
		%end;
		%if &varcount=TRUE %then
			%do;
				%let pair = %sysfunc(catx(=, "&name."n, %quote(&prefix.)_%sysfunc(putn(&i., z6.))));
			%end;
		%else
			%do;
				%let pair = %sysfunc(catx(=, "&name."n, %quote(&prefix.)_&name.));
			%end;
		%if %nrbquote(&lab.)= %then %do;
			%let pair2 = %sysfunc(catx(=, "&name."n, "%quote(&prefix.) &name."));
		%end;
		%else %do;
			%let pair2 = %sysfunc(catx(=, "&name."n, "%quote(&prefix.) &lab."));
		%end;
		%let rename_statement=&rename_statement. &pair.;
		%let relabel_statement=&relabel_statement. &pair2.;

	%end;
	%if &debug eq TRUE %then %do;
		%put &=rename_statement.;
		%put &=relabel_statement.;
	%end;
	proc datasets lib=&lib. nolist;
		modify &dsin.;
		label %quote(&relabel_statement.);
		rename %quote(&rename_statement.);
		run;
	quit;

%mend column_prefix;

/*%column_prefix(lib=work, dsin=tmp, prefix=TMP, varcount=FALSE);*/
/* Copyright (c) 2022 by SAS Institute Inc., Cary, NC USA 27513 */

%macro column_prefix(lib=, dsin=, prefix=, varcount=);
	%local i;
	%local n;

	proc contents data=&lib..&dsin. out=_out_ order=varnum noprint; run;

	proc sort data=_out_;
		by varnum;
	run;

	proc sql noprint;
		select name, compress(label, ',;') into :names separated by "|", :labels separated by "|" from _out_;
	quit;

	%let N=&sqlobs.;
	%let n_global=&sqlobs.;
	%if &debug. eq TRUE %then %do;
		%put &=N.;
		%put &=names.;
		%put &=labels.;
	%end;

	%let rename_statement=;
	%let relabel_statement=;

	%do i=1 %to &N.;
		%let name = %scan(&names., &i., "|", M);
		%let lab = %scan(%nrbquote(&labels.), &i., "|", M);
		%if &debug eq TRUE %then %do;
			%put &=i. &=name.;
			%put &=i. &=lab.;
		%end;
		%if &varcount=TRUE %then
			%do;
				%let pair = %sysfunc(catx(=, "&name."n, %quote(&prefix.)_%sysfunc(putn(&i., z6.))));
			%end;
		%else
			%do;
				%let pair = %sysfunc(catx(=, "&name."n, %quote(&prefix.)_&name.));
			%end;
		%if %nrbquote(&lab.)= %then %do;
			%let pair2 = %sysfunc(catx(=, "&name."n, "&prefix. &name."));
		%end;
		%else %do;
			%let pair2 = %sysfunc(catx(=, "&name."n, "&prefix. &lab."));
		%end;
		%let rename_statement=&rename_statement. &pair.;
		%let relabel_statement=&relabel_statement. &pair2.;

	%end;
	%if &debug eq TRUE %then %do;
		%put &=rename_statement.;
		%put &=relabel_statement.;
	%end;
	proc datasets lib=&lib. nolist;
		modify &dsin.;
		label &relabel_statement.;
		rename &rename_statement.;
		run;
	quit;

%mend column_prefix;

/*
DATA employees;
attrib emp_id label="Hallo (%)";
attrib firstname label=")(/)((?%?))";
attrib name label="Test - hallo 6 a.m.";
attrib department label="normal label";
attrib salary format=8.;
INPUT emp_id $ firstname $ name $ department $ salary;
CARDS;
E1001 John Smith Sales 50000
E1002 Jane Doe Marketing 60000
E1003 Peter Jones IT 45000
;
RUN;

%let debug=TRUE;
options mprint mlogic;

%column_prefix(lib=work, dsin=employees, prefix=BLD, varcount=FALSE); 
*/