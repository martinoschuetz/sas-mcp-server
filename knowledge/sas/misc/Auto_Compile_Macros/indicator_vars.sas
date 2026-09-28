data FILTER_FOR_GEOFENCE_OUT;
	set FILTER_FOR_GEOFENCE_OUT;
	id = _n_;
run;

/* 
Creates a number of indicator variables from a nominal variable.
Factors above the accumulated cutoff (percentage number) will be renamed to other.
*/
%macro indicator_vars(ds=,var=,cutoff=);
	/* Set factors of variable above cutoff to "OTHER" */
	%if &cutoff. < 100 %then
		%do;

			proc hpdmdb data=&ds. classout=&ds._classout;
				class &var.;
			run;

			proc sort data=&ds._classout;
				by descending freqpercent;
			run;

			data &ds._classout;
				set &ds._classout;
				retain freqpercent_cumul 0;
				freqpercent_cumul = sum(freqpercent_cumul,freqpercent);
				new_var = craw;

				if freqpercent_cumul > &cutoff. then
					do;
						new_var = "OTHER";
					end;
			run;

			proc sql noprint;
				create table hlp(drop=&var.) as 
					select t1.*, t2.new_var 
						from &ds. t1
							left join &ds._classout t2 on (t1.&var. = t2.craw);
			quit;

			data &ds.(rename=(new_var=&var.));
				set hlp;
			run;

		%end;

	/* Compute number of factors of variable without missings */
	proc sql noprint;
		/*		select distinct upcase(left(trim(&var.))) as label into : labels separated by ';'*/
		select distinct kupcase(kstrip(&var.)) as label into : labels separated by ';'
			from &ds.
				order by label;
	quit;

	%let N=&sqlobs.;
	%put N=&n.;
	%put labels=&labels.;

	/* Compute whether variable contains missings */
	proc sql noprint;
		select nmiss(distinct &var.) as no_miss into : no_missings from &ds.;
	quit;

	%put &=no_missings;

	data &ds.;
		set &ds.;

		%do i= 1 %to %sysevalf(&n.- &no_missings.);

			/* %put &=i; */
			%let label=%qkscan(&labels.,&i.,';');

			/* %put &=label; */
			attrib &var._&i. length=3 label="&var._&i.: &label.";
			&var._&i=kindex(kupcase(&var.),"&label.") gt 0;
		%end;

		%if %sysevalf(&no_missings. > 0, boolean) %then
			%do;
				&var._&n.=(sum(of &var._1-&var._%sysevalf(&n.-1))) eq 0;
				label &var._&n.="&var._&n.: 'MISSING'";
			%end;
	run;

%mend;


%indicator_vars(ds=FILTER_FOR_GEOFENCE_OUT,var=afb_runway,cutoff=100);
