%macro tag_variable(dsin=, dsout=, var=);

	proc summary data=&dsin.;
		var &var.;
		output out=work.&var._stats p1= p5= p95= p99= / autoname;
	run;

	data _null_;
		set work.&var._stats(obs=1);
		call symput("&var._P1",&var._P1);
		call symput("&var._P5",&var._p5);
		call symput("&var._P95",&var._p95);
		call symput("&var._P99",&var._p99);
	run;

	data &dsout.;
		set &dsin.;
		&var._P1  = ifn(&var. < &&&var._P1, 1, 0);
		&var._P5  = ifn(&var. < &&&var._P5, 1, 0);
		&var._P95 = ifn(&var. > &&&var._P95, 1, 0);
		&var._P99 = ifn(&var. > &&&var._P99, 1, 0);
	run;

	proc delete data=work.&var._stats; run;

%mend tag_variable;
/*
%tag_variable(dsin=data.env3, dsout=data.env3_tagged, var=env_3);
*/
