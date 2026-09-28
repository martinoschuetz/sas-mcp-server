/************************************************************************/
/* This example illustrates fitting and comparing two Machine           */   
/* Learning algorithms for predicting the binary target in the          */
/* BANK data set. The steps include:                                    */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Load data set into CAS                                        */
/*                                                                      */
/* (2) PERFORM SUPERVISED LEARNING                                      */
/*     a) Fit model using Logistic Regression                           */
/*     b) Fit a model using a Decision Tree                             */
/*                                                                      */
/* (3) EVALUATE AND IMPLEMENT                                           */
/*     a) Score the data                                                */
/*     b) Assess model performance                                      */
/*     c) Generate ROC and Lift charts                                  */
/************************************************************************/

/************************************************************************/
/* Setup and initialize for later use in the program                    */
/************************************************************************/
/* Specify a libref to the input tables */
libname locallib '/opt/sasinside/DemoData';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;

/* Specify the data set names */
%let sasdata          = locallib.bank;                     
%let casdata          = mycaslib.bank;            
%let partitioned_data = mycaslib.bank_part;  

/* Specify the data set inputs and target */
%let class_inputs    = cat_input1 cat_input2;
%let interval_inputs = logi_rfm1-logi_rfm12; 
%let target          = b_tgt;

/* Specify a folder path to write the temporary output files */
%let outdir = &USERDIR/Output; 


/************************************************************************/
/* Load data into CAS if needed. Data should have been loaded in        */
/* step 1, it will be loaded here after checking if it exists in CAS    */
/************************************************************************/
%if not %sysfunc(exist(&casdata)) %then %do;
  proc casutil;
    load data=&sasdata casout="bank";
  run;
%end;


/************************************************************************/
/* Partition the data into training and validation                      */
/************************************************************************/
proc partition data=&casdata partition samppct=70;
  by b_tgt;
  output out=&partitioned_data copyvars=(_ALL_);
run;


/************************************************************************/
/* LOGISTIC REGRESSION predictive model                                 */
/************************************************************************/
proc logselect data=&partitioned_data;
  class b_tgt &class_inputs.;
  model b_tgt(event='1')=&class_inputs. &interval_inputs.;
  partition rolevar=_partind_(train='1' validate='0');
  selection method=backward;
  code file="&outdir./logselect_score.sas" pcatall;
run;


/************************************************************************/
/* Score the data using the generated logistic model score code         */
/************************************************************************/
data mycaslib._scored_logistic;
  set &partitioned_data;
  %include "&outdir./logselect_score.sas";
run;


/************************************************************************/
/* Assess model performance                                             */
/************************************************************************/
ods exclude all;
proc assess data=mycaslib._scored_logistic;
  input p_b_tgt1;
  target &target / level=nominal event='1';
  fitstat pvar=p_b_tgt0/ pevent='0';
  by _partind_;
  ods output fitstat  = logit_fitstat 
             rocinfo  = logit_rocinfo 
             liftinfo = logit_liftinfo;
run;
ods exclude none;


/************************************************************************/
/* DECISION TREE predictive model                                       */
/************************************************************************/
proc treesplit data=&partitioned_data;
  input &interval_inputs. / level=interval;
  input &class_inputs. / level=nominal;
  target b_tgt / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
  grow entropy;
  prune c45;
  code file="&outdir./treeselect_score.sas";
run;


/************************************************************************/
/* Score the data using the generated tree model score code             */
/************************************************************************/
data mycaslib._scored_tree;
  set &partitioned_data;
  %include "&outdir./treeselect_score.sas";
run;


/************************************************************************/
/* Assess tree model performance                                        */
/************************************************************************/
ods exclude all;
proc assess data=mycaslib._scored_tree;
  input p_b_tgt1;
  target &target / level=nominal event='1';
  fitstat pvar=p_b_tgt0/ pevent='0';
  by _partind_;
  ods output fitstat  = tree_fitstat 
             rocinfo  = tree_rocinfo 
             liftinfo = tree_liftinfo;
run;
ods exclude none;


/*************************************************************************/
/*  Create ROC and Lift plots (both models) using validation data        */
/*************************************************************************/
ods graphics on;

data all_rocinfo;
  set logit_rocinfo(keep=sensitivity fpr c _partind_ in=l where=(_partind_=0))
      tree_rocinfo(keep=sensitivity fpr c _partind_ in=t where=(_partind_=0));
      
  length model $ 16;
  select;
      when (l) model='Logistic';
      when (t) model='Tree';
     end;
run;

data all_liftinfo;
  set logit_liftinfo(keep=depth lift cumlift _partind_ in=l where=(_partind_=0))
      tree_liftinfo(keep=depth lift cumlift _partind_ in=t where=(_partind_=0));
      
  length model $ 16;
  select;
      when (l) model='Logistic';
      when (t) model='Tree';
  end;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUC (using validation data) ";
proc sql;
  select distinct model, c from all_rocinfo order by c desc;
quit;

/* Draw ROC charts */ 
proc sgplot data=all_rocinfo aspect=1;
  title "ROC Curve (using validation data) ";
  xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05; 
  yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
  lineparm x=0 y=0 slope=1 / transparency=.7;
  series x=fpr y=sensitivity / group=model;
run;
   
/* Draw lift charts */   
proc sgplot data=all_liftinfo; 
  title "Lift Chart (using validation data)";
  yaxis label=' ' grid;
  series x=depth y=lift / group=model markers markerattrs=(symbol=circlefilled);
run;

title;
ods graphics off;
