/***************************************************************/
/*                                                             */
/*          S A S   S A M P L E   L I B R A R Y                */
/*                                                             */
/*     NAME: nlpse06                                           */
/*   TITLE: Maximum Likelihood Weibull Model (nlpse06)         */
/* PRODUCT: OR                                                 */
/*  SYSTEM: ALL                                                */
/*    KEYS: OR                                                 */
/*   PROCS: OPTMODEL                                           */
/*    DATA:                                                    */
/*                                                             */
/* SUPPORT:                             UPDATE:                */
/*     REF:                                                    */
/*    MISC: Example 6 from the Nonlinear Programming Solver    */
/*          chapter of Mathematical Programming.               */
/*                                                             */
/***************************************************************/

/* Observed data */

data pike;
   input days cens @@;
   datalines;
143  0  164  0  188  0  188  0
190  0  192  0  206  0  209  0
213  0  216  0  220  0  227  0
230  0  234  0  246  0  265  0
304  0  216  1  244  1
;

/* Solve maximum likelihood estimation problem */
cas sascas1;

proc cas; setsessopt/metrics=true; run; quit;

libname mycaslib cas sessref=sascas1;

proc optmodel sessref=sascas1;
   set OBS;
   num days {OBS};
   num cens {OBS};
   read data pike into OBS=[_N_] days cens;
   var sig   >= 1.0e-6 init 10;
   var c     >= 1.0e-6 init 10;
   var theta >= 0 <= min {i in OBS: cens[i] = 0} days[i] init 10;

   impvar fi {i in OBS} =
      (if cens[i] = 0 then
         log(c) - c * log(sig) + (c - 1) * log(days[i] - theta)
      )
    - ((days[i] - theta) / sig)^c;
   max logf = sum {i in OBS} fi[i];

   set VARS = 1.._NVAR_;
   num mycov {i in VARS, j in 1..i};
   
   solve with NLP / algorithm=activeset covest=(cov=2 covout=mycov);
   
   /* Print parameter estimates and covariance matrix */
   
   print sig c theta;
   print mycov;
   create data covdata from [i j]={i in VARS, j in 1..i}
      var_i=_VAR_[i].name var_j=_VAR_[j].name mycov;
quit;


