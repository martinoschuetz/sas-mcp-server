/************************************************************************/
/* This example illustrates fitting and comparing several Machine       */ 
/* Learning algorithms for predicting the binary target in the          */
/* BANK data set. The steps include:                                    */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Load data set into CAS                                        */
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
/* RANDOM FOREST predictive model                                       */
/************************************************************************/
proc forest data=&partitioned_data ntrees=50 intervalbins=20 minleafsize=5 
            outmodel=mycaslib.forest_model;
  input &interval_inputs. / level = interval;
  input &class_inputs. / level = nominal;
  target b_tgt / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
run;


/************************************************************************/
/* Score the data using the generated RF model                          */
/************************************************************************/
proc forest data=&partitioned_data inmodel=mycaslib.forest_model noprint;
  output out=mycaslib._scored_RF copyvars=(_ALL_);
run;


/************************************************************************/
/* GRADIENT BOOSTING MACHINES predictive model                          */
/************************************************************************/
proc gradboost data=&partitioned_data ntrees=10 intervalbins=20 maxdepth=5 
               outmodel=mycaslib.gb_model;
  input &interval_inputs. / level = interval;
  input &class_inputs. / level = nominal;
  target b_tgt / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
run;


/************************************************************************/
/* Score the data using the generated GBM model                         */
/************************************************************************/
proc gradboost  data=&partitioned_data inmodel=mycaslib.gb_model noprint;
  output out=mycaslib._scored_GB copyvars=(_ALL_);
run;


/************************************************************************/
/* NEURAL NETWORK predictive model                                      */
/************************************************************************/
proc nnet data=&partitioned_data;
  target b_tgt / level=nom;
  input &interval_inputs. / level=int;
  input &class_inputs. / level=nom;
  hidden 5;
  train outmodel=mycaslib.nnet_model;
  partition rolevar=_partind_(train='1' validate='0');
  ods exclude OptIterHistory;
run;


/************************************************************************/
/* Score the data using the generated NN model                          */
/************************************************************************/
proc nnet data=&partitioned_data inmodel=mycaslib.nnet_model noprint;
  output out=mycaslib._scored_NN copyvars=(_ALL_);
run;


/************************************************************************/
/* SUPPORT VECTOR MACHINE predictive model                              */
/************************************************************************/
proc svmachine data=&partitioned_data(where=(_partind_=1));
  kernel polynom / deg=2;
  target b_tgt;
  input &interval_inputs. / level=interval;
  input &class_inputs. / level=nominal;
  savestate rstore=mycaslib.svm_astore_model;
  ods exclude IterHistory;
run;


/************************************************************************/
/* Score data using ASTORE code generated for the SVM model             */
/************************************************************************/
proc astore;
  score data=&partitioned_data out=mycaslib._scored_SVM 
        rstore=mycaslib.svm_astore_model copyvars=(b_tgt _partind_);
run;


/************************************************************************/
/* Assess                                                               */
/************************************************************************/
%macro assess_model(prefix=, var_evt=, var_nevt=);
  proc assess data=mycaslib._scored_&prefix.;
    input &var_evt.;
    target b_tgt / level=nominal event='1';
    fitstat pvar=&var_nevt. / pevent='0';
    by _partind_;
  
    ods output
      fitstat=&prefix._fitstat 
      rocinfo=&prefix._rocinfo 
      liftinfo=&prefix._liftinfo;
run;
%mend assess_model;

ods exclude all;
%assess_model(prefix=RF, var_evt=p_b_tgt1, var_nevt=p_b_tgt0);
%assess_model(prefix=SVM, var_evt=p_b_tgt1, var_nevt=p_b_tgt0);
%assess_model(prefix=GB, var_evt=p_b_tgt1, var_nevt=p_b_tgt0);
%assess_model(prefix=NN, var_evt=p_b_tgt1, var_nevt=p_b_tgt0);
ods exclude none;


/************************************************************************/
/* ROC and Lift Charts using validation data                            */
/************************************************************************/
ods graphics on;

data all_rocinfo;
  set SVM_rocinfo(keep=sensitivity fpr c _partind_ in=s where=(_partind_=0))
      GB_rocinfo(keep=sensitivity fpr c _partind_ in=g where=(_partind_=0))
      NN_rocinfo(keep=sensitivity fpr c _partind_ in=n where=(_partind_=0))
      RF_rocinfo(keep=sensitivity fpr c _partind_ in=f where=(_partind_=0));
      
  length model $ 16;
  select;
    when (s) model='SVM';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (n) model='NeuralNetwork';
  end;
run;

data all_liftinfo;
  set SVM_liftinfo(keep=depth lift cumlift _partind_ in=s where=(_partind_=0))
      GB_liftinfo(keep=depth lift cumlift _partind_ in=g where=(_partind_=0))
      NN_liftinfo(keep=depth lift cumlift _partind_ in=n where=(_partind_=0))
      RF_liftinfo(keep=depth lift cumlift _partind_ in=f where=(_partind_=0));
      
  length model $ 16;
  select;
    when (s) model='SVM';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (n) model='NeuralNetwork';
  end;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUC (using validation data) ";
proc sql;
  select distinct model, c from all_rocinfo order by c desc;
quit;

/* Draw ROC charts */         
proc sgplot data=all_rocinfo aspect=1;
  title "ROC Curve (using validation data)";
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
