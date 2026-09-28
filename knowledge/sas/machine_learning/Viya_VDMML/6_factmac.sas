/************************************************************************/
/* This example showcases a sample Machine Learning workflow for        */
/* supervised learning using a Factorization Machine on a ratings data  */
/* set. A Factorization Machine performs matrix factorization that can  */
/* be used for recommendation or predictive modelling with sparse       */
/* transactional data.                                                  */
/*                                                                      */
/* The steps include:                                                   */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Load data set into CAS                                        */
/*                                                                      */
/* (2) PERFORM SUPERVISED LEARNING                                      */
/*     a) Fit a model by using Factorization Machine for reviews        */
/*        based on simulated data                                       */
/*                                                                      */
/* (3) EVALUATE AND IMPLEMENT                                           */
/*     a) Score the data using Factorization Machine model              */
/*     b) Assess model performance                                      */
/************************************************************************/

/************************************************************************/
/* Setup and initialize for later use in the program                    */
/************************************************************************/
/* Specify a libref to the input tables */
libname locallib '/opt/sasinside/DemoData';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;

/* Specify a folder path to write the temporary output files */
%let outdir = &USERDIR/Output; 


/************************************************************************/
/* Load data into CAS                                                   */
/************************************************************************/
/* Load train data */
%if not %sysfunc(exist(mycaslib.reviews)) %then %do;
  proc casutil;
    load data=locallib.reviews casout="reviews";
  run;
%end;

/* Load score data */
%if not %sysfunc(exist(mycaslib.reviews_test)) %then %do;
  proc casutil;
    load data=locallib.reviews_test casout="reviews_test";
  run;
%end;


/************************************************************************/
/* Modeling:                                                            */
/* The Factorization Machine will run with the following settings:      */ 
/*   The optimization will stops after 20 iterations                    */
/*   The model will have 5 factors                                      */
/*   The optimization learning step is 0.15                             */
/************************************************************************/
proc factmac data=mycaslib.reviews 
  maxiter=20
  nfactors=5
  learnstep=0.15
  seed=12345;

  input user item / level=nominal;
  target rating / level=interval;

  output out=mycaslib.reviews_scored copyvar=(user item rating);
  savestate rstore=mycaslib.fm_astore_model;
run;


/************************************************************************/
/* Scoring using ASTORE                                                 */
/************************************************************************/
/* Scoring the reviews test dataset based on the model developed */
proc astore;
  score data=mycaslib.reviews_test
        out=mycaslib.reviews_test_scored
        rstore=mycaslib.fm_astore_model
        copyvars=(user item rating);
run; 


/************************************************************************/
/* Assessment                                                           */
/************************************************************************/
/* Select the min and the max ratings for the scored reviews dataset */
proc sql noprint;
  select min(rating), max(rating) into :minrtg, :maxrtg
  from mycaslib.reviews_test_scored;
quit;

/* Plot the predicted vs actual ratings for the scored reviews dataset */
proc sgplot data=mycaslib.reviews_test_scored;
  title 'Scored Ratings';  
  *scatter x=rating y=p_rating / transparency=0.9 name='Scatter';
  heatmap x=rating y=p_rating / colormodel=twocolorramp ybinsize=0.1 xbinsize=0.1;      
  xaxis grid label='Actual Rating' min=&minrtg max=&maxrtg offsetmax=0.05;
  yaxis grid label='Predicted Rating' min=&minrtg max=&maxrtg;
run;
