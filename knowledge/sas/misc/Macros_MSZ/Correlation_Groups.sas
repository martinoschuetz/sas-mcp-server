/*
proc compare data=data.train compare=data.test outnoequal out=comp; run;

data data.train;
	set data.train;
	dataset = "TRAIN";
run;

data data.test;
	set data.test;
	dataset = "TEST";
run;

data data.train_test;
	set data.train;
run;

proc append base=data.train_test data=data.test ; run;

proc hpdmdb data=data.train_test varout=data.train_test_varout;
	var _numeric_;
run;

proc hpcorr data=data.train(drop=id TARGET) out=data.train_corr(where=(_TYPE_ eq 'CORR')) noprint; 
	var _numeric_;
run;

data data.train_corr;
	set data.train_corr;
	n1 = _n_;
run;
*/

proc hpcorr data=sashelp.baseball out=baseball_corr(where=(_TYPE_ eq 'CORR')) noprint; 
	var _numeric_;
run;

data baseball_corr;
	set baseball_corr;
	n1 = _n_;
run;

/*proc sort data=data.train_corr; by _name_; run;*/
PROC TRANSPOSE DATA=baseball_corr
	OUT=baseball_corr_list(rename=(_NAME_=var1 vars=var2 corr1=corr))
	PREFIX=Corr
	NAME=vars;
	by n1 _name_;
	VAR _numeric_;
quit;

/* Only use upper triangular values above a certain treshold*/
data baseball_corr_list(where=(abs(corr) gt 0.8));
	retain n2;
	set baseball_corr_list(where=(var2 ne 'n1'));
	by n1;
	if first.n1 then n2 = 1; else n2 = n2 +1;
	if (n2 > n1);
run; 

proc optgraph
	graph_direction = undirected
	data_links = baseball_corr_list(keep=var1 var2 rename=(var1=from var2=to))
	out_nodes = baseball_corr_communities;
	community
		resolution_list = 0.001
		algorithm = parallel_label_prop
		out_level = CommLevelOut
		out_community = CommOut
		out_overlap = CommOverlapOut
		out_comm_links = CommLinksOut;
run;
proc sort data=baseball_corr_communities nodupkey dupout=baseball_corr_comm_dupout; by community_1; run;

proc sql;
	select node into :vars separated by ' ' from baseball_corr_comm_dupout
quit;
%put &=vars;

/* Just keep class representative in original data set */
data data.train;
	set data.train(drop=&vars);
run;

/* EM Metadaten Manipulation */
/*filename x &EM_FILE_CDELTA_TRAIN;
data _null_;
file x;
put ‘if upcase(NAME) = “variable-name” then ROLE=”REJECTED”;’;
run;
*/
proc contents data=data.train_test out=vars; run;
proc sql;
	select name into :names separated by ' ' from vars; 
quit;
%put &=names.;

%COUNT_MV(data=data.train_test,vars=&names.);
%MV_PROFILING (data=data.train_test,vars=_ALL_,ODS=YES,varclus=YES,princomp=YES,ncomp=2,sample=1,seed=123456,order=ALPHA);

/*
	ToDo:
		- IMPUTE, TRANSFORM, Unterschiedlich Tranform mit vielen Prädiktoren, Variablen Selektion mit HPFOREST,
			evtl. Test bewerten und neue Lernmenge, Champion noch einmal auf gesamter Menge trainieren
*/