/* SAS code */
%macro RSquare(dsin=, orig=, score=, text=);
	proc means data=&dsin. noprint;
		var &orig.;
		output out=_stats_ mean=orig_mean;
	run;

	data _null_;
		set _stats_(obs=1);
		call symputx("orig_mean",orig_mean);
	run;
	%put &=orig_mean;

	data _tmp;
		set &dsin.;
		res_mean_2 	= (&orig. - &orig_mean.) * (&orig. - &orig_mean.);
		res_orig_2 	= (&orig. - &score.) * (&orig. - &score.);
	run;

	proc means data=_tmp noprint;
		var res_mean_2 res_orig_2;
		output out=_stats_ sum= / autoname;
	run;

	data _null_;
		set _stats_(obs=1);
		call symputx("res_mean_2_sum",res_mean_2_sum);
		call symputx("res_orig_2_sum",res_orig_2_sum);
	run;
	%put &=res_mean_2_sum;
	%put &=res_orig_2_sum;

	data _NULL_;
		if 0 then set &dsin. nobs=n;
 		call symputx("n",n);
 		stop;
	run;

	%let R2	= %sysevalf(1 - (&res_orig_2_sum. / &res_mean_2_sum.));
	%put Partition=&text.: &=n. observations, &=R2.;

	proc odstext;
	  p "&text. Partition R2 = &R2." / style=[fontsize=14pt font_weight=bold just=center];
	run;
		
	/* Clean-up */
	proc datasets library=work kill nodetails nolist nowarn; run; quit;
%mend RSquare;

*%RSquare(dsin=sashelp.cars(keep=msrp invoice), orig=msrp, score=invoice, text=Training);