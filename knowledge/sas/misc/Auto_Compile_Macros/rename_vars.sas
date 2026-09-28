/*
	The macro renames variables using a new prefix.
	It is assumed, that the original variables use the following naming convention:
	A prefix and a consecutive number like: col1, col2, col3, ...
*/

%macro rename_vars(ds=, oldprefix=, newprefix=);

	proc contents data=&ds. out=contents noprint; run;

	proc sql noprint;
		select distinct count(name) into :no_cols from contents where index(name,"&oldprefix.") > 0;
	quit;

	%put &=no_cols;

	data &ds.;
		set &ds.;
		%let k=1;

		%do %while(&k <= &no_cols);
			rename &oldprefix.&k  = &newprefix.&k;
			%let k = %eval(&k + 1);
		%end;
	run;

%mend;
/*
data test;
       input id $1 col1 3-5 col2 7-9 col3 11-13 misc $15;
       cards;
1 0.1 0.2 0.3 a
2 0.2 0.3 0.4 b
3 0.3 0.4 0.5 c
4 0.4 0.5 0.6 d
5 0.5 0.6 0.7 e
;
run; 

%rename_vars(ds=test, oldprefix=col, newprefix=new);
*/