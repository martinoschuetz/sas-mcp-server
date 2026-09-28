/************************************************************************/
/* This example illustrates autotuning random forest and gradient       */ 
/* boosting models using the BANK data set. The steps include:          */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Load data set into CAS                                        */
/*                                                                      */
/* (2) PERFORM AUTOTUNING                                               */
/*     a) Tune number of trees in Random Forest                         */
/*     b) Tune number of trees and learning rate in Gradient Boosting   */
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
/* Autotune ntrees in Random Forest                                     */
/************************************************************************/
/* Lower Bound for ntrees   : 25                                        */
/* Upper Bound for ntrees   : 50                                        */
/* Starting value for ntrees: 50                                        */
/*                                                                      */
/* Population size          : 2 (number of evalutions in one iteration) */
/* Max number of iterations : 2                                         */
/*                                                                      */
/* So a maximum of 4 (Population size * Max number of iterations) models  
   will be built and the best among them is chosen based on
   the misclassification rate of validation data
*/
proc forest data=&partitioned_data intervalbins=10 minleafsize=5;
  input &interval_inputs. / level = interval;
  input &class_inputs. / level = nominal;
  target b_tgt / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');  
  autotune maxiter=2 popsize=2 useparameters=custom
           tuneparms=(ntrees(lb=25 ub=50 init=50));
  ods output TunerResults=rf_tuner_results;           
run;

/* Plot Tuner Results */         
proc sgplot data=rf_tuner_results;
  title "Random Forest Tuner Results";
  scatter x=evaluation y=misclasserr / datalabel=ntree markerattrs=(symbol=circlefilled);
  footnote italic justify=left "The number above the dot represents ntrees hyperparameter";
run;
title;
footnote;

/************************************************************************/
/* Autotune ntrees and learning rate in GBM                             */
/************************************************************************/
/* Lower Bound for ntrees   : 25                                        */
/* Upper Bound for ntrees   : 50                                        */
/* Starting value for ntrees: 50                                        */
/*                                                                      */
/* List of values used for learning rate: 0.1, 0.125, 0.15, 0.175, 0.2  */
/*                                                                      */
/* Population size          : 2 (number of evalutions in one iteration) */
/* Max number of iterations : 2                                         */
/************************************************************************/
/* So a maximum of 4 (Population size * Max number of iterations) models  
   will be built and the best among them is chosen based on
   the misclassification rate of validation data   
*/
proc gradboost data=&partitioned_data intervalbins=10 maxdepth=5;
  input &interval_inputs. / level = interval;
  input &class_inputs. / level = nominal;
  target b_tgt / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');  
  autotune maxiter=2 popsize=2 useparameters=custom
           tuneparms=(ntrees(lb=25 ub=50 init=50) learningrate(values=0.1 0.125 0.15 0.175 0.2));
    ods output TunerResults=gbm_tuner_results;     
run;

/* Append ntrees and learning rate for labeling */
data gbm_tuner_results;
  set gbm_tuner_results;
  ntree_lrate = catx(' / ', ntree, learningrate);
run;

/* Plot Tuner Results */         
proc sgplot data=gbm_tuner_results;
  title "Gradient Boosting Tuner Results";
  scatter x=evaluation y=misclasserr / datalabel=ntree_lrate markerattrs=(symbol=circlefilled);
  footnote italic justify=left "The numbers above the dot represents ntrees / learning rate hyperparameters";
run;
title;
footnote;
