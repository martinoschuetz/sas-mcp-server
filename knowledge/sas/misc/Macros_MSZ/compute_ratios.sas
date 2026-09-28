/* Macro requires all columns with a similar prefix (e.g. "Event") and length=8. */
%macro compute_ratios(ds,ds_out,dropvars,offset);
	%local novars column_names column_labels;

	/* Comput number of variables in ds. */
	proc contents data=&ds(drop=&dropvars.) out=cont noprint; run;

	proc sql noprint;
		select count(*) into :novars from cont;
	quit;

	/* Compute string of variable names of ds. */
	proc sql noprint;
		select strip(name) into: column_names separated by ';'
			from cont order by name;
	quit;

	/* Compute string of label names of ds. */
	proc sql noprint;
		select strip(label) into: column_labels separated by ';'
			from cont order by label;
	quit;

	%let prefix = %scan(%scan(&column_names.,1,';',I),1,'_',I);

	data &ds_out(drop=Event_0);
		%do i=1 %to &novars;
			attrib &prefix._&i. length=8;
		%end;

		%do i=1 %to &novars;
			%let label_name = %scan(&column_labels,&i.,';',I);
			attrib 	&prefix._%eval(&i. + &offset.)
					label="&label_name._Ratio" length=8;
		%end;

		set &ds;

		%do i=1 %to &novars;
			&prefix._%eval(&i. + &offset.) = &prefix._&i. / Event_0;
		%end;
	run;
%mend;