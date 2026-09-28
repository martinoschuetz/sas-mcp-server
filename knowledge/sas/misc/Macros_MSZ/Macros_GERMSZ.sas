/*	List of Macros from Martin Schütz (germsz).
	OPTIONS MPRINT SYMBOLGEN MLOGIC;
	Further options for debugging purposes. */

/* Counts distinct occurrences in colum 'name' in data set 'data'. */
%macro count_distinct(data=,name=,out=out);
	proc sql noprint;
		create table &out as
		select count(DISTINCT &name) as &name._Count from &data;
	quit;
%mend count_distinct;

/* 	Write top n rows wrt to column 'column' into a new data set 'out'.
	If set 'keep' identifies the only column to keep. */
%MACRO top_n(data=,column=,n=,out=,keep=);

	proc sort data=&data;
		by descending &column;
	run;

	%IF &keep=. %then
		%do;
			data &out;
				set &data(obs=&n);
			run;
		%END;
	%ELSE
		%DO;
			data &out;
				set &data(keep=&keep obs=&n);
			run;
		%END;
%MEND top_n;

/*	Calculates a measure for a numeric column and assigns the value
	to a macro variable '&columnname._&measure'.*/
%macro measure_column(data=,columnname=,measure=);
	%global &columnname._&measure;

	proc means data=&data noprint;
		var &columnname;
		output out=out(drop=_TYPE_ _FREQ_) &measure=&measure;
	run;

	data _null_;
   		set out;
   		if _n_=1 then call symput("&columnname._&measure",&measure);
		else stop;
	run;
%mend;

