/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 6: Strategies for Efficient and Effective Simulation
 ***********************************************************************/

%macro ODSOff(); /* Call prior to BY-group processing */
ods graphics off;
ods exclude all;
ods noresults;
%mend;

%macro ODSOn(); /* Call after BY-group processing */
ods graphics on;
ods exclude none;
ods results;
%mend;


/********************************************************************
 The Design of a Simulation Study
 *******************************************************************/

%let N = 20;
%let NumSamples = 1000;                /* number of samples    */  
data RegSim;
call streaminit(1);
do i = 1 to &N;
   x = (i-1)/(&N-1);
   do beta = 0 to 3 by 0.2;
      eta = 1 + beta*x;                /* linear predictor     */
      do SampleID = 1 to &NumSamples;
         y = eta + rand("Normal");
         output;
      end; 
   end;                                /* end beta loop        */
end;                                   /* end observation loop */
run;

proc sort data=RegSim out=Sim;
   by beta SampleID;
run;

/* Turn off output when calling PROC for simulation */
%ODSOff
proc reg data=Sim;
   by beta SampleID;
   model y = x;
   test x=0;
   ods output TestANOVA=TestAnova;
quit;
%ODSOn

/* 3. Construct an indicator variable for observations that reject H0 */
data Results;
   set TestANOVA(where=(Source="Numerator"));
   Reject = (ProbF <= 0.05);           /* indicator variable    */
run;

/* count number of times H0 was rejected */
proc freq data=Results noprint;
   by beta;
   tables Reject / nocum binomial(level='1');
   output out=Est binomial;
run;

title "Preliminary Power of Test for Beta=0, OLS";
title2 "Normal Errors, Equally Spaced Design, N = &N, &NumSamples Samples";
proc sgplot data=Est noautolegend;
   series x=beta y=_BIN_;
   scatter x=beta y=_BIN_ / yerrorlower=L_Bin yerrorupper=U_Bin;
   yaxis min=0 max=1 label="Power (1 - P[Type II Error])" grid;
   xaxis label="Beta" grid;
run;

/********************************************************************
 Writing Efficient Simulations
 *******************************************************************/

/* suppress output to ODS destinations */
ods graphics off;
ods exclude all; 
ods noresults;

ods graphics on;
ods exclude none; 
ods results;

%macro ODSOff;                 /* Call prior to BY-group processing */
ods graphics off;
ods exclude all;
ods noresults;
%mend;

%macro ODSOn;                  /* Call after BY-group processing    */
ods graphics on;
ods exclude none;
ods results;
%mend;

%let N = 31;                           /* size of each sample */
%let NumSamples = 10000;               /* number of samples   */  
/* 1. Simulate data */
data SimNormal;
call streaminit(123);
do SampleID = 1 to &NumSamples;
   do i = 1 to &N;
      x = rand("Normal");
      output;
   end;
end;

%ODSOff
proc means data=SimNormal;
   by SampleID;
   var x;
   ods output Summary=Desc;
run;
%ODSOn

/***********************************************************************/

options nonotes;  
options notes;  

/***********************************************************************/

/*************************************/
/* DO NOT USE THIS CODE: INEFFICIENT */
/*************************************/
%macro Simulate(N, NumSamples);
options nonotes;                       /* turn off notes to log     */
proc datasets nolist; 
   delete OutStats;                    /* delete data if it exists  */
run;

%do i = 1 %to &NumSamples;
   data Temp;                          /* create one sample         */
   call streaminit(0);
   do i = 1 to &N;
      x = rand("Uniform");
      output;
   end;
   run;

   proc means data=Temp noprint;       /* compute one statistic     */
      var x;
      output out=Out mean=SampleMean;
   run;
   
   proc append base=OutStats data=Out;          /* accumulate stats */
   run;  
%end;
options notes;
%mend;

/* call macro to simulate data and compute ASD */
%Simulate(10, 100)               /* means of 100 samples of size 10 */

/***********************************************************************/

proc iml;
size = do(500, 2000, 250);    /* 500, 1000, ..., 2000               */
time = j(1, ncol(size));      /* allocate vector for results        */
call randseed(12345); 
do i = 1 to ncol(size);
   n = size[i];
   r = j(n*(n+1)/2, 1);       /* generate lower triangular elements */
   call randgen(r, "uniform");
   A = sqrvech(r);            /* create symmetric matrix            */

   t0 = time();
   evals = eigval(A);
   time[i] = time()-t0;       /* elapsed time for computation       */
end;
create eigen var {"Size" "Time"}; append; close;
quit;

proc sgplot data=eigen;
   title "Performance of Eigenvalue Computation";
   series x=Size y=Time / markers;
   yaxis grid label="Time to Compute Eigenvalues (s)";
   xaxis grid label="Size of Matrix";
run;
