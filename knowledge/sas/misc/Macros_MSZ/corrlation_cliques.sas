/* 	Aim: Compute highly correlated cliques 
Requirement: No constant or missing columns. Only numeric columns */
data vdemo05.hlp;
	set vdemo05.ABT200626_MERGED_ASC_CLEANSED;
	drop 'Chargen-Nr'n Time: Ausbeute: Standard: Harm: Gehalt:;
run;

proc cardinality data=vdemo05.hlp2 outcard=vdemo05.outcard;
	var _all_;
run;

proc sql noprint;
	select _VARNAME_ into :vars separated by ' ' from vdemo05.outcard(where=(_RLEVEL_ eq "CLASS" and _CARDINALITY_ eq 2));
quit;

%put &=sqlobs.;
%put &=vars.;

data test;
	set vdemo05.hlp(keep=C2_Et_O1001Par_du);
run;

proc freq data=test;
	table C2_Et_O1001Par_du /out=_freq;
run;

/* ToDo: Investigate: The insufficient memory error. Obviously, results are computed.*/
proc correlation data=vdemo05.hlp outp=vdemo05._corr nosimple;
	var _numeric_;
run;

data _corr(where=(_TYPE_ eq 'CORR'));
	set vdemo05._corr;
	n1=_n_;
run;

proc sort data=_corr;
	by n1 _name_;
run;

PROC TRANSPOSE DATA=_corr OUT=_corr_list(rename=(_NAME_=var1 vars=var2 
	corr1=corr)) PREFIX=Corr NAME=vars;
	by n1 _name_;
	VAR _numeric_;
quit;

/* Only use upper triangular values above a certain treshold*/
data vdemo05._corr_list2;
	retain n2;
	set _corr_list(where=(var2 ne 'n1') );
	by n1;

	if first.n1 then
		n2=1;
	else n2=n2 +1;

	if (n2 > n1);
	corrabs=abs(corr);
run;

option nomprint nomlogic;

data correlation_groups;
	attrib threshold	length=8	label="Correlation threshold";
	attrib no_vars		length=8	label="Number of variables above threshold";
	attrib pairs		length=8	label="Numer of pairs for threshold";
	attrib nocliques	length=8	label="Number of cliques for threshold";
	attrib bigclique	length=8	label="Biggest clique";
	input threshold pairs nocliques bigclique;
	datalines;
run;

%macro clique_loop;
	%local i;
	%let i = 1.0;

	%do %while (%sysevalf(&i. ge 0));
		%put &=i;

		/* Find cliques of highly correlated variables */
		data vdemo05._corr_list_filtered(keep=from to);
			set vdemo05._corr_list2(rename=(var1=from var2=to));
			where corrabs ge &i.;
		run;

		data _NULL_;
			if 0 then
				set vdemo05._corr_list_filtered nobs=n;
			call symputx('nrows',n);
			stop;
		run;

		%put &=nrows;

		proc optnetwork links=vdemo05._corr_list_filtered outNodes=vdemo05.NodeSetOut;
			connectedComponents out=vdemo05.ConCompOut algorithm=parallel;
		run;

		%put &=_OROPTNETWORK_;

		proc sql noprint;
			select max(concomp),max(nodes), sum(nodes) into :maxcliques, :biggest_clique, :no_vars from vdemo05.ConCompOut;
		quit;

		%put &=no_vars;
		%put &=maxcliques;
		%put &=biggest_clique;

		data loop;
			threshold 	= &i.;
			no_vars		= &no_vars;
			pairs		= &nrows.;
			nocliques	= &maxcliques.;
			bigclique	= &biggest_clique.;
		run;

		proc append base=correlation_groups data=loop;
		run;

		%let i = %sysevalf(&i - 0.01);
	%end;
%mend clique_loop;

%clique_loop;
%load_base_cas(lib=work, dsin=correlation_groups, viyalib=viyademo05, dsviya=correlation_groups);
ods graphics / reset;
ods graphics on;

proc sgplot data=correlation_groups;
	series x=threshold y=pairs;
	series x=threshold y=nocliques;
	series x=threshold y=bigclique;
run;

ods graphics off;

/* check whether variables with correlations ne 1 exist. */
data vdemo05._corr_list_ne_one;
	set vdemo05._corr_list2;
	where corrabs ne 1;
run;

/* Find cliques of highly correlated variables */
data vdemo05._corr_list_one(keep=from to);
	set vdemo05._corr_list2(rename=(var1=from var2=to));
	where corrabs eq 1;
run;

data _NULL_;
	if 0 then
		set vdemo05._corr_list_one nobs=n;
	call symputx('nrows',n);
	stop;
run;

%put nobs=&nrows;

proc optnetwork links=vdemo05._corr_list_one outNodes=vdemo05.NodeSetOut;
	connectedComponents out=vdemo05.ConCompOut algorithm=parallel;
run;

%put &=_OROPTNETWORK_;

proc sql noprint;
	select max(concomp),max(nodes) into :maxcliques, :biggest_clique from vdemo05.ConCompOut;
quit;

%put &=maxcliques;
%put &=biggest_clique;

/* Split necessary due to length limitation of macro variables */
data hlp;
	set vdemo05.nodesetout;
	col=cats("'", node, "'n");
run;

/* 	This part is handcrafted since the first clique has to many variables. */
data _null_;
	set hlp(where=(concomp=1) obs=1);
	call symputx("Clique1", node);
run;

%put &=Clique1;

proc sql noprint;
	select col into :cl1_1 separated by " " from hlp(obs=1500 where=(concomp=1 and 
		node ne "&Clique1."));
	select col into :cl1_2 separated by " " from hlp(firstobs=1501 obs=3000 
		where=(concomp=1 and node ne "&Clique1."));
	select col into :cl1_3 separated by " " from hlp(firstobs=3001 
		where=(concomp=1 and node ne "&Clique1."));
quit;

%put &=cl1_1.;
%put &=cl1_2.;
%put &=cl1_3.;

data work.ABT200626_MERGED_ASC_REDUCED;
	set work.ABT200626_MERGED_ASC_CLEANSED(drop=&cl1_1. &cl1_2. &cl1_3.);
run;

options mprint;

%macro clique_lists;
	%do i=2 %to &maxcliques.;

		data _null_;
			set hlp(where=(concomp=&i.) obs=1);
			call symputx("Clique&i.", node);
		run;

		%put &&Clique&i.;

		proc sql noprint;
			select col into :cl&i. separated by " " from hlp(where=(concomp=&i. and node 
				ne "&&Clique&i."));
		quit;

		%put &&cl&i.;

		data work.ABT200626_MERGED_ASC_REDUCED;
			set work.ABT200626_MERGED_ASC_REDUCED(drop=&&cl&i.);
		run;

	%end;
%mend clique_lists;

%clique_lists;
%load_base_cas(lib=work, dsin=ABT200626_MERGED_ASC_REDUCED, viyalib=viyademo05, 
	dsviya=ABT200626_REDUCED2_MSZ);