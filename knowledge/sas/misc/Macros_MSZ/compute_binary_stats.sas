/*
data data1;
	input id $ test1 test2;
	datalines;
sub01 1 0
sub02 1 0
sub03 0 0
sub04 0 1
sub05 1 1
sub06 1 1
sub07 1 1
sub08 0 0
sub09 1 0
sub10 1 1
sub11 1 1
sub12 1 1
sub13 0 0
sub14 0 0
sub15 1 1
sub16 1 1
sub17 1 1
sub18 1 0
sub19 0 0
sub20 0 1
sub21 0 1
sub22 1 1
sub23 0 0
sub24 0 0
sub25 1 1
sub26 0 0
sub27 0 0
sub28 0 0
sub29 0 0
sub30 1 1
sub31 1 0
sub32 0 0
sub33 0 0
sub34 0 0
sub35 1 1
sub36 0 0
sub37 1 1
sub38 1 0
sub39 0 0
sub40 0 0
;
run;
*/

%macro compute_binary_stats(ds=,orig=,pred=,prefix=, id=);

	data data2;
		set &ds.;

		if &orig.=1 then
			do;
				if &pred.=1 then
					result_c12="TP";
				else if &pred.=0 then
					result_c12="FN";
			end;
		else if &orig.=0 then
			do;
				if &pred.=1 then
					result_c12="FP";
				else if &pred.=0 then
					result_c12="TN";
			end;
	run;

	proc sort data=data2;
		by &orig. &pred.;
	run;

	data main1 (drop=id result_c12);
		set data2;
		by &orig.;
		retain tp tn fp fn;

		if (first.&orig.) then
			do;
				tp=0;
				tn=0;
				fp=0;
				fn=0;
			end;

		if (result_c12 in ("TP")) then
			tp=tp+1;

		if (result_c12 in ("TN")) then
			tn=tn+1;

		if (result_c12 in ("FN")) then
			fn=fn+1;

		if (result_c12 in ("FP")) then
			fp=fp+1;
		else;

		if (last.&orig.) then
			output;
	run;

	data main2;
		set main1;
		tntp=tn+tp;
		fnfp=fn+fp;
	run;

	proc sql;
		create table main3 as
			select sum(tp) as tp, sum(tn) as tn, sum(fp)as fp, sum(fn) as fn, sum(tntp) as
				tntp, sum(fnfp) as fnfp
			from main2;
	quit;

	/* Compute SENSITIVITY, SPECIFICITY AND ACCURACY */
	proc sql;
		create table stats&id. as
			select tp/(tp+fn) as sensitivity_&prefix., tn/(tn+fp) as specificity_&prefix., (tn+tp)/(tn+tp+fn+fp) as accuracy_&prefix.
			from main3;
		;
	quit;

	/* ASYMPTOTIC AND EXACT 95% CONFIDENCE INTERVAL */
	/*
	proc transpose data=main3 out=t_main;
		var tp tn fn fp tntp fnfp;
	run;

	data table32 (drop=_name_ col1);
		length group $20;
		set t_main;
		count=col1;

		if _name_="tp" then
			do;
				group="Sensitivity";
				response=0;
				output;
			end;
		else if _name_="fn" then
			do;
				group="Sensitivity";
				response=1;
				output;
			end;
		else if _name_="tn" then
			do;
				group="Specificity";
				response=0;
				output;
			end;
		else if _name_="fp" then
			do;
				group="Specificity";
				response=1;
				output;
			end;
		else if _name_="tntp" then
			do;
				group="Accuracy";
				response=0;
				output;
			end;
		else if _name_="fnfp" then
			do;
				group="Accuracy";
				response=1;
				output;
			end;
	run;

	proc sort data=table32;
		by group;
	run;

	proc freq data= table32;
		weight count;
		by group;
		tables response/alpha=0.05 binomial(p=0.5) out=stats_confidence&id.;
		exact binomial;
	run;
*/	ods exclude all;
	proc datasets lib=work nodetails;
		delete main: data2;
	run;
	ods exclude none;
%mend;

/* %compute_binary_stats(ds=data1,orig=test1,pred=test2,prefix=orig, id=1);*/
