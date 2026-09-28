/************************************************************************/
/* This example showcases fitting and assessing Generalized Linear      */
/* Models using the GENSELECT Procedure                                 */
/* The steps include:                                                   */
/*                                                                      */
/* (1) PREPARE                                                          */
/*     a) Load data set into CAS                                        */
/*                                                                      */
/* (2) Perform Modeling on the Interval Target                          */ 
/*     a) Assuming normal distribution, using identity link             */
/*     b) Plot the prediction residuals                                 */   
/*                                                                      */
/* (3) PERFORM Modeling on the Count Target                             */
/*     a) Fit a Generalized Linear Model                                */
/*     b) Identify high leverage observations from the training data    */
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
/* The Interval Target Model                                            */
/************************************************************************/
/* Partition the data into training and validation */
proc partition data=&casdata partition samppct=70;
	output out=&partitioned_data copyvars=(_ALL_);
run;

/* Assuming normal distribution, fit a GLM using the Genselect procedure */
proc genselect data=&partitioned_data;
  class &class_inputs.;
  model int_tgt=&interval_inputs. &class_inputs. / dist=normal link=identity;
  selection method=forward(select=sbc stop=sbc choose=sbc) hierarchy=none;
  partition rolevar=_partind_(train='1' validate='0');
  output out=mycaslib.residuals predicted residual h copyvars=(_partind_);
run;

/* Plot the residuals from the validation partition of the data */
data mycaslib.residuals ;
  set mycaslib.residuals (where=(_partind_=0 & _resraw_ ne .));
  rename _pred_=p_int_tgt _resraw_=residual;
run;
	
proc sgplot data=mycaslib.residuals;
  scatter x=p_int_tgt y=residual / markerattrs=(size=4);
  title "Residuals vs. Predicted Values for the Interval Target";
run;
title;


/************************************************************************/
/* The Count Target Model                                               */
/************************************************************************/
/* Partition the data into training and validation for the Count Target */
proc partition data=&casdata partition samppct=70;
  by cnt_tgt;
  output out=&partitioned_data copyvars=(_ALL_);
run;

/* Fit a GLM model to the count target using the Genselect Procedure */   
proc genselect data=&partitioned_data;
  class &class_inputs.;
  model cnt_tgt=&interval_inputs. &class_inputs. / dist=negbinomial link=log;
  selection method=backward(select=sbc stop=sbc choose=sbc) hierarchy=none;
  partition rolevar=_partind_(train='1' validate='0');
  output out=mycaslib.outlier difchisq copyvars=(_partind_ account);
run;

/* Create a table with the top 100 high leverage observations from the training data */
data mycaslib.highlev;
  set mycaslib.outlier (where=(_partind_=1 & _difchisquare_ > 100));
run;

proc sort data=mycaslib.highlev out=highlev; 
  by descending _difchisquare_; 
run;

proc print data=highlev (obs=100);
  title 'Top 100 high leverage observations from Training data';
run;
title;

