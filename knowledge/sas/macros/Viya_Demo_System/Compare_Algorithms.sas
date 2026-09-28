cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" 	metrics=true);

caslib _all_ assign;

/* Specify a libref for local data sets */
libname locallib '/opt/data/demodata';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;

/************LOAD DATA INTO CAS*********/
%if not %sysfunc(exist(mycaslib.big_organics)) %then %do;

/* You can load data using a "load" statement in PROC CASUTIL */
proc casutil;
	load data=locallib.big_organics casout="big_organics";
run;

%end;

/***********************Explore the data*****************************/
proc cardinality data=MYCASLIB.BIG_ORGANICS maxlevels=20 
		outcard=MYCASLIB.varSummaryTemp out=MYCASLIB.levelDetailTemp;
run;

proc print data=MYCASLIB.varSummaryTemp label;
	var _varname_ _fmtwidth_ _type_ _rlevel_ _more_ _cardinality_ _nmiss_ 
		_missfmt_ _min_ _max_ _mean_ _stddev_ _kurtosis_;
	title 'Variable Summary';
run;

proc sgplot data=mycaslib.varsummarytemp;
	vbar  _varname_ / response=_nmiss_;
run;

proc print data=MYCASLIB.levelDetailTemp (obs=20) label;
	title 'Level Details';
run;

proc sgplot data=mycaslib.levelDetailTemp(where=(_index_ eq .));
	vbar  _varname_ / response=_freq_;
run;

proc delete data=MYCASLIB.varSummaryTemp MYCASLIB.levelDetailTemp;
run;


/************IMPUTE MISSINGS*****************/
proc varimpute data=MYCASLIB.BIG_ORGANICS;
	input DemAffl DemAge PromSpend PromTime / ctech=mean;
	input DemGender DemReg DemTVReg PromClass / ntech=mode;
	output out=MYCASLIB.BIG_ORGANICS_imputed copyvars=(TargetBuy TargetAmt);
run;

/**************Identify predictors**************/
proc varreduce data=MYCASLIB.BIG_ORGANICS_IMPUTED;
	class IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass;
	reduce supervised TargetBuy=IM_DemAffl IM_DemAge IM_PromSpend IM_PromTime 
		IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass / varianceexplained=0.9;
	ods output selectionsummary=Work._VarSelection_summary_;
run;

/****************Partition the data*************************/
proc partition data=MYCASLIB.BIG_ORGANICS_Imputed partind samppct=30 seed=1234;
	by TargetBuy;
	output out=mycaslib.sampled;
run;

/*****************Train predictive Models********************/
/*Gradient Boosting*/
proc gradboost data=MYCASLIB.SAMPLED;
	partition role=_PartInd_ (validate='1');
	target TargetBuy / level=nominal;
	input IM_DemAffl IM_DemAge IM_PromSpend IM_PromTime / level=interval;
	input IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass / level=nominal;

	/*autotune tuningparameters=(ntrees samplingrate vars_to_try(init=10)
	learningrate lasso ridge) searchmethod=random;*/
	ods output FitStatistics=Work._Gradboost_FitStats_ 
		VariableImportance=Work._Gradboost_VarImp_;
	score out=MYCASLIB.scored_gb copyvars=(TargetBuy IM_DemAffl IM_DemAge 
		IM_PromSpend IM_PromTime IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass 
		_PartInd_);
run;

proc sgplot data=Work._Gradboost_FitStats_;
	title3 'Misclassifications by Number of Iterations';
	title4 'Training vs. Validation';
	series x=Trees y=MiscTrain;
	series x=Trees y=MiscValid /lineattrs=(pattern=dot thickness=2);
	yaxis label='Misclassification Rate';
	label Trees='Number of Iterations';
	label MiscTrain='Training';
	label MiscValid='Validation';
run;

title3;

proc sgplot data=Work._Gradboost_VarImp_;
	title3 'Variable Importance';
	hbar variable / response=importance nostatlabel categoryorder=respdesc;
run;

title3;

proc delete data=Work._Gradboost_VarImp_;
run;

proc delete data=Work._Gradboost_FitStats_;
run;

/*Logistic Regression*/
proc logselect data=MYCASLIB.SAMPLED;
	partition role=_PartInd_ (validate='1');
	class IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass;
	model TargetBuy(event='1')=IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass 
		IM_DemAffl IM_DemAge IM_PromSpend IM_PromTime / link=logit;
	selection method=backward
        (stop=sbc choose=sbc) hierarchy=none;
	output out=MYCASLIB.scored_lg predicted copyvars=(_all_);
run;

data mycaslib.scored_lg;
	set mycaslib.scored_lg;
	P_TargetBuy1=_PRED_;
	P_TargetBuy0=1-_PRED_;
run;

/*Forest*/
proc forest data=MYCASLIB.SAMPLED;
	partition role=_PartInd_ (validate='1');
	target TargetBuy / level=nominal;
	input IM_DemAffl IM_DemAge IM_PromSpend IM_PromTime / level=interval;
	input IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass / level=nominal;
	score out=mycaslib.scored_rf copyvars=(TargetBuy IM_DemAffl IM_DemAge 
		IM_PromSpend IM_PromTime IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass 
		_PartInd_);
	savestate rstore=MYCASLIB.score;
run;

/*Neural*/
libname _tmpcas_ cas;

proc nnet data=MYCASLIB.SAMPLED missing=mean;
	partition role=_PartInd_ (validate='1');
	target TargetBuy / level=nominal;
	input IM_DemAffl IM_DemAge IM_PromSpend IM_PromTime / level=interval;
	input IM_DemGender IM_DemReg IM_DemTVReg IM_PromClass / level=nominal;
	architecture mlp direct;
	hidden 50;
	hidden 50;
	train outmodel=_tmpcas_._Nnet_model_;
	optimization regL2=0.1;
	score out=MYCASLIB.scored_nn copyvars=(_all_);
run;

proc delete data=_tmpcas_._Nnet_model_;
run;

/********************ASSESS*********************************/
/************************************************************************/
/* This example illustrates fitting and comparing several Machine       */
/* Learning algorithms for predicting the binary target in the          */
/* HMEQ data set. The steps include:                                    */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Check data is loaded into CAS                                 */
/*                                                                      */
/* (2) PERFORM SUPERVISED LEARNING                                      */
/*     a) Fit a model using a Random Forest                             */
/*     b) Fit a model using Gradient Boosting                           */
/*     c) Fit a model using a Neural Network                            */
/*     d) Fit a model using a Support Vector Machine                    */
/*                                                                      */
/* (3) EVALUATE AND IMPLEMENT                                           */
/*     a) Score the data                                                */
/*     b) Assess model performance                                      */
/*     c) Generate ROC and Lift charts                                  */
/************************************************************************/
/************************************************************************/
/* Assess                                                               */
/************************************************************************/
%macro assess_model(prefix=, var_evt=, var_nevt=);
	proc assess data=mycaslib.scored_&prefix.;
		by _partind_;

		/*   input P_TargetBuy1;*/
		input &var_evt.;
		target TargetBuy / level=nominal event='1';

		/* fitstat pvar=P_TargetBuy0 / pevent='0';*/
		fitstat pvar=&var_nevt. / pevent='0';
		ods output fitstat=&prefix._fitstat rocinfo=&prefix._rocinfo 
			liftinfo=&prefix._liftinfo;
	run;

%mend assess_model;

%let target=TargetBuy;
ods exclude all;
%assess_model(prefix=GB, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=lg, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=rf, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=nn, var_evt=p_&target.1, var_nevt=p_&target.0);
ods exclude none;

/************************************************************************/
/* ROC and Lift Charts using validation data                            */
/************************************************************************/
ods graphics on;

data all_rocinfo_val;
	set rf_rocinfo(in=s) GB_rocinfo(in=g) lg_rocinfo(in=l) nn_rocinfo(in=n);
	length model $ 16;

	select;
		when (s) model='Random Forest';
		when (g) model='GradientBoosting';
		when (l) model='Logistic Regression';
		when (n) model='Neural Network';
	end;

	if _partind_=1 then
		output;
run;

data all_liftinfo_val;
	set RF_liftinfo(in=s) GB_liftinfo(in=g) nn_liftinfo(in=n) lg_liftinfo(in=l);
	length model $ 16;

	select;
		when (s) model='Random Forest';
		when (g) model='GradientBoosting';
		when (l) model='Logistic Regression';
		when (n) model='Neural Network';
	end;

	if _partind_=1 then
		output;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUC (using validation data) ";

proc sql;
	select distinct model, c from all_rocinfo_val order by c desc;
quit;

/* Draw ROC charts */
proc sgplot data=all_rocinfo_val aspect=1;
	title "ROC Curve (using validation data)";
	xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
	yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
	lineparm x=0 y=0 slope=1 / transparency=.7;
	series x=fpr y=sensitivity / group=model;
run;

/* Draw lift charts */
proc sgplot data=all_liftinfo_val;
	title "Lift Chart (using validation data)";
	yaxis label=' ' grid;
	series x=depth y=lift / group=model markers markerattrs=(symbol=circlefilled);
run;

/*Score Final Model*/
proc astore;
	score data=MYCASLIB.BIG_ORGANICS_Imputed out=MYCASLIB.score 
		rstore=MYCASLIB.SCORE;
run;

proc contents data=MYCASLIB.score;
run;

cas mySession terminate;