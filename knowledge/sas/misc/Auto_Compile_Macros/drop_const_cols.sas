options mprint mlogic;
/*
	ToDo: If condition for HP and non-HP procs.
*/
/*
	marco drop_const_cols identifies constant colums in data set using high-performance procedure.
	Additionally the macro determines the data set content and computes univariate measures.
	dsin:				Name of input table to be analyzed
	dsout:				Name of reduced table, i.e. input without constant columns
	content_table:		Name of table which keeps descriptions of input table
	class_meas:			Name of table which keeps frequency counts for character variables
	class_drop_list:	Name of table which hold list of dropped character variables 
	num_meas:			Name of table which keeps univariate measures for numeric variables
	num_drop_list:		Name of table which hold list of dropped numeric variables
	drop_vars:			List of variables of input table which should be excluded from analysis
*/
%macro drop_const_cols( dsin=, dsout=, content_table=content,
						class_meas=c_meas, class_drop_list=c_drop, 
						num_meas=n_meas, num_drop_list=n_drop,
						drop_vars=);

	proc contents data=&dsin. out=&content_table. nodetails short noprint; run;

	ods exclude all;

	/* Compute univariate measures for class and numeric variables. */
	proc hpdmdb data=&dsin.(drop=&drop_vars.)
		varout=&num_meas. classout=&class_meas.;
		var _numeric_;
		class _character_;
	run;

	/* Identify constant numeric columns. */
	proc sql;
		create table &num_drop_list. as
			select name from &num_meas. where ((std eq 0) or (std eq .));
	quit;
	%let COUNT_NUM=&SYSNOBS.;
	proc sql;
		select name into :drop_cols_meas separated by " " from &num_drop_list.;
	quit;

	/* Identify constant character columns. */
	proc sql;
		create table &class_drop_list. as
			select name from &class_meas. group by name having (count(name) le 1);
	quit;
	%let COUNT_CLASS=&SYSNOBS.;
	proc sql;
		select name into :drop_cols_class separated by " " from &class_drop_list.;
	quit;

	%put &=COUNT_NUM.;
	%put &=COUNT_CLASS.;

	%if (&COUNT_NUM. ne 0) and (&COUNT_CLASS. ne 0) %then 
		%do;
			%put &=drop_cols_meas;
			%put &=drop_cols_class;
			data &dsout.;
				set &dsin.(drop=&drop_cols_meas. &drop_cols_class.);
			run;
		%end;
	%else
		%do;
			%if (&COUNT_NUM. ne 0) %then 
				%do;
					%put &=drop_cols_meas;
					data &dsout.;
						set &dsin.(drop=&drop_cols_meas.);
					run;
				%end;
			%else
				%do;
					%if (&COUNT_CLASS. ne 0) %then 
						%do;
							%put &=drop_cols_class;
							data &dsout.;
								set &dsin.(drop=&drop_cols_class.);
							run;
						%end;
					%else
						%do;
							data &dsout.;
								set &dsin.;
							run;
							%put No constant or empty columns;
						%end;
				%end;
		%end;
		
	ods exclude none;

%mend drop_const_cols;


/* Macro test data */
/*
data testdata;
	length id m1-m3 8. c1-c3 $1;
	input id m1-m3 c1-c3;
	datalines;
1 1.0 . 1.0 a . a
2 1.0 . 2.0 a . b
3 1.0 . 3.0 a . c
4 1.0 . 4.0 a . d
5 1.0 . 5.0 a . e
;
*/
/* Example call WITH constant and missings */
/*
%drop_const_cols(
	dsin=work.testdata,
	dsout=work.testdata_red,
	content_table=work.testdata_cont,
	class_meas=work.testdata_c_meas,
	class_drop_list=work.testdata_c_drop,
	num_meas=work.testdata_n_meas,
	num_drop_list=work.testdata_n_drop,
	drop_vars=id
);
*/
/* Example call WITHOUT constant and missings */
/*
%drop_const_cols(
	dsin=sashelp.class,
	dsout=class_red,
	content_table=class_cont,
	class_meas=class_c_meas,
	class_drop_list=class_c_drop,
	num_meas=class_n_meas,
	num_drop_list=class_n_drop,
	drop_vars=
);
*/