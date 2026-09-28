/*
 * ToDo:
 * Macro pro Verfahren
 * Einheitliche Cross-Validation?
 * Beste Einstellung auf Training / Validation ausführen
 * Sampling
 *
 */
options mprint;
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");
cas _all_ list;

/* Specify a libref for local data sets */
libname locallib clear;
libname locallib '/home/sasdemo/Examples/germsz/data';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib clear;
libname mycaslib cas caslib=casuser;

%if not %sysfunc(exist(mycaslib.hmeq)) %then %do;

proc casutil ;
	load data=locallib.hmeq casout="hmeq";
run;
%end;

%let target=bad;
%let target_level=nominal;
%let nominal=reason job;
%let interval=loan mortdue value yoj derog delinq clage ninq clno debtinc;
%let popsize=10;
%let popsize_step=2;
%let maxiter=40;
%let maxiter_step=5;
%let kfold=10;
%let measure=AUC;

data mycaslib.hlp;
	set mycaslib.hmeq(obs=100);
run;
%let abt=mycaslib.hlp;


%macro loop;
	%local first_pass;
	%let first_pass=1;

	%do i=2 %to &popsize. %by &popsize_step.;

		%do j=5 %to &maxiter. %by &maxiter_step.;

			proc gradboost data=mycaslib.hlp noprint;
				target &target. / level=&target_level.;
				input  &interval. / level=interval;
				input  &nominal. / level=nominal;
				autotune 
					popsize=&popsize. maxiter=&maxiter. kfold=&kfold. objective=&measure.;
				ods output FitStatistics=Work._Gradboost_FitStats_&i._&j. 
					VariableImportance=Work._Gradboost_VarImp_&i._&j. 
					BestConfiguration=_GradBoost_BestConf_&i._&j.;
			run;

			proc transpose data=work._gradboost_bestconf_&i._&j. out=temp;
				id parameter;
				var value;
			run;

			data temp;
				set temp;
				length popsize maxiter 8.;
				length step $5;
				popsize=&i.;
				maxiter=&j.;
				step="&i._&j.";
			run;

			proc transpose data=Work._Gradboost_VarImp_&i._&j. out=temp2;
				id Variable;
				var Importance Std;
			run;

			data temp3;
				set Work._Gradboost_FitStats_&i._&j.;
				length popsize maxiter 8.;
				length step $5;
				popsize=&i.;
				maxiter=&j.;
				step="&i._&j.";
			run;

			%if &first_pass. eq 1 %then
				%do;
					%let first_pass = 0;
					data base_grad_boost; set temp;	run;
					data base_grad_boost_imp; set temp2; run;
					data base_grad_boost_fit; set temp3; run;
				%end;
			%else
				%do;
					proc append base=base_grad_boost new=temp; run;
					proc append base=base_grad_boost_imp new=temp2;	run;
					proc append base=base_grad_boost_fit new=temp3;	run;
				%end;
		%end;
	%end;
%mend;

%loop;

data locallib.autotune_results;
	set base_grad_boost;
run;

proc sort data=locallib.autotune_results;
	by descending 'Area Under Curve'n;
run;

data _null_;
	set locallib.autotune_results;
	if _n_ eq 1 then do;
		call symput('Evaluation',Evaluation);
		call symput('Number_of_Trees','Number of Trees'n);
		call symput('Number_of_Variables_to_Try','Number of Variables to Try'n);
		call symput('Learning_Rate','Learning Rate'n);
		call symput('Sampling_Rate','Sampling Rate'n);
		call symput('Lasso',Lasso);
		call symput('Ridge',Ridge);
	end;
run;
%put &=Evaluation.;
%put &=Number_of_Trees.;
%put &=Number_of_Variables_to_Try.;
%put &=Learning_Rate.;
%put &=Sampling_Rate.;
%put &=Lasso.;
%put &=Ridge.;

/* Stratified Sampling producing 50% training, 30% validation, and 20% test data. */
proc partition data=&abt partind samppct=30 samppct2=20 seed=1234;
	by &target.;
	output out=&abt._partitioned;
run;

proc gradboost data=&abt._partitioned 
	LASSO=&Lasso. learningrate=&Learning_Rate. NTREES=&Number_of_Trees. RIDGE=&Ridge.
	samplingrate=&Sampling_Rate. VARS_TO_TRY=&Number_of_Variables_to_Try.;
	partition role=_PartInd_ (train='0' validate='1' test='2');
	target &target. / level=&target_level.;
	input  &interval. / level=interval;
	input  &nominal. / level=nominal;
	SAVESTATE RSTORE=mycaslib.gradboost_optimal;
	ods output FitStatistics=Work._Gradboost_FitStats_ 	VariableImportance=Work._Gradboost_VarImp_;
	score out=&abt._scored_gb copyvars=(_all_);
run;



data mycaslib.base_grad_boost_imp;
	set base_grad_boost_imp;
run;

proc cardinality data=mycaslib.base_grad_boost_imp(where=(_NAME_='Importance')) 
		outcard=mycaslib.base_grad_boost_imp_card;
	var _numeric_;
run;

proc sgplot data=mycaslib.base_grad_boost_imp_card;
	title 'Mean Variable Importance';
	hbar _VARNAME_ / response=_mean_ nostatlabel categoryorder=respdesc;
run;


proc sgplot data=base_grad_boost_fit;
	title 'ASE by Number of Iterations grouped by run';
	series x=Trees y=ASETrain / group=step;
	yaxis label='Average Square Error';
	label Trees='Number of Iterations';
run;

title3;

/*
 * proc delete data=Work._Gradboost_VarImp_; run;
 */
/*
 * proc delete data=Work._Gradboost_FitStats_; run;
 */
cas mySession terminate;