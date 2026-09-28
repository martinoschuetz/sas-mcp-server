/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 5: Using Simulation to Evaluate Statistical Techniques
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
 Confidence Interval for a Mean
 *******************************************************************/

%let N = 50;                                /* size of each sample  */
%let NumSamples = 10000;                    /* number of samples    */  
/* 1. Simulate obs from N(0,1) */
data Normal(keep=SampleID x);
call streaminit(123);
do SampleID = 1 to &NumSamples;             /* simulation loop      */
   do i = 1 to &N;                          /* N obs in each sample */
      x = rand("Normal");                   /* x ~ N(0,1)           */
      output;
   end;
end;
run;  

/* 2. Compute statistics for each sample */
proc means data=Normal noprint;
   by SampleID;
   var x;
   output out=OutStats mean=SampleMean lclm=Lower uclm=Upper;
run;  

ods graphics / width=6.5in height=4in;
proc sgplot data=OutStats(obs=100);
   title "95% Confidence Intervals for the Mean";
   scatter x=SampleID y=SampleMean;
   highlow x=SampleID low=Lower high=Upper / legendlabel="95% CI";
   refline 0 / axis=y;
   yaxis display=(nolabel);
run;

/* how many CIs include parameter? */
data OutStats;  set OutStats;
   ParamInCI = (Lower<0 & Upper>0);           /* indicator variable */
run;

/* Nominal coverage probability is 95%. Estimate true coverage. */
proc freq data=OutStats;
   tables ParamInCI / nocum; 
run;

/**********************/
/* Answer to exercise */
/**********************/
%macro DoExercise(N, NumSamples);
   title "Exercise with N=&N and NumSamples=&NumSamples";
   /* 1. Simulate obs from N(0,1) */
   data Normal(keep=trial SampleID x);
   call streaminit(123);
   do trial=1 to 10;
   do SampleID = 1 to &NumSamples;             /* simulation loop      */
      do i = 1 to &N;                          /* N obs in each sample */
    x = rand("Normal");                   /* x ~ N(0,1)           */
    output;
      end;
   end;
   end;
   run;  

   /* 2. Compute statistics for each sample */
   proc means data=Normal noprint;
      by trial SampleID;
      var x;
      output out=OutStats mean=SampleMean lclm=Lower uclm=Upper;
   run;  

   /* how many CIs include parameter? */
   data OutStats;  set OutStats;
      ParamInCI = (Lower<0 & Upper>0);       /* indicator variable */
   run;
   /* Nominal coverage probability is 95%. Estimate true coverage. */
   proc freq data=OutStats noprint;
      by trial;
      tables ParamInCI / nocum out=Trials; 
   run;

   proc means data=Trials(where=(ParamInCI=0)) mean std min max range;
      var percent;
   run;
   title;
%mend;

%DoExercise(50, 10000);             /* std and range of P are small */
%DoExercise(50, 1000);              /* more variation in P          */
/**********************/


/***********************************************************************/


/* exponential data */
%let N = 50;                                /* size of each sample  */
%let NumSamples = 10000;                    /* number of samples    */

data Exp(keep=SampleID x);
call streaminit(321);
do SampleID = 1 to &NumSamples;             /* simulation loop      */
   do i = 1 to &N;                          /* N obs in each sample */
      x = rand("Expo") - 1;                 /* x ~ Exp(1) - 1       */
      output;
   end;
end;
run;

/* 2. Compute confidence interval for each sample */
proc means data=Exp noprint;
  by SampleID;
  var x;
  output out=OutStats mean=SampleMean lclm=Lower uclm=upper;
run;

/* 3. Analyze sampling distribution of statistic */
/* how many CIs don't include parameter? Create indicator variable */
data OutStats;
  set OutStats;
  ParamInCI = (Lower<0 & Upper>0);
run;

/* Nominal coverage probability is 95%. Estimate true coverage. */
proc freq data=OutStats;
  tables ParamInCI / nocum;     /* count CIs that include parameter */
run;

/***********************************************************************/

%let N = 50;                          /* size of each sample */
%let NumSamples = 10000;              /* number of samples   */  
proc iml;
call randseed(321);
x = j(&N, &NumSamples);               /* each column is a sample    */
call randgen(x, "Normal");            /* x ~ N(0,1)                 */

SampleMean = mean(x);                 /* mean of each column        */
s = std(x);                           /* std dev of each column     */
talpha = quantile("t", 0.975, &N-1);
Lower = SampleMean - talpha * s / sqrt(&N);
Upper = SampleMean + talpha * s / sqrt(&N);

ParamInCI = (Lower<0 & Upper>0);      /* indicator variable         */
PctInCI = ParamInCI[:];               /* pct that contain parameter */
print PctInCI;
quit;

/********************************************************************
 Assessing the Two-Sample t Test for Equality of Means
 *******************************************************************/

/* test sensitivity of t test to equal variances */
%let n1 = 10;
%let n2 = 10;
%let NumSamples = 10000;                /* number of samples        */

/* Scenario 1: (x1 | c=1) ~ N(0,1);  (x1 | c=2) ~ N(0,1);           */
/* Scenario 2: (x2 | c=1) ~ N(0,1);  (x2 | c=2) ~ N(0,10);          */
data EV(drop=i);
label x1 = "Normal data, same variance"
      x2 = "Normal data, different variance";
call streaminit(321);
do SampleID = 1 to &NumSamples;
   c = 1;                               /* sample from first group  */
   do i = 1 to &n1;
      x1 = rand("Normal");  
      x2 = x1;              
      output;
   end;
   c = 2;                               /* sample from second group */
   do i = 1 to &n2;
      x1 = rand("Normal");
      x2 = rand("Normal", 0, 10);
      output;
   end;
end;
run;

/* 2. Compute statistics */
%ODSOff                          /* suppress output                 */
proc ttest data=EV; 
   by SampleID; 
   class c;                      /* compare c=1 to c=2              */
   var x1-x2;                    /* run t test on x1 and also on x2 */
   ods output ttests=TTests(where=(method="Pooled")); 
run; 
%ODSOn                           /* enable output                   */

/* 3. Construct indicator var for tests that reject H0 at 0.05 significance */ 
data Results; 
   set TTests; 
   RejectH0 = (Probt <= 0.05);           /* H0: mu1 = mu2           */
run; 

/* 3b. Compute proportion: (# that reject H0)/NumSamples */ 
proc sort data=Results; 
   by Variable; 
run; 

proc freq data=Results; 
   by Variable; 
   tables RejectH0 / nocum;
run;

/***********************************************************************/

/* test assumption of normal data */
/* Scenario 3: (x3 | c=1)~Exp(1);  (x3 | c=2)~Exp(1);  */
/* Scenario 4: (x4 | c=1)~N(0,10); (x4 | c=2)~Exp(10); */
data NND(drop=i);
label x3 = "Exponential data, same variance"
      x4 = "Normal vs. Exponential data, difference variance";
call streaminit(321);
do SampleID = 1 to &NumSamples;
   c = 1;
   do i = 1 to &n1;
      x3 = rand("Exponential");              /* mean = StdDev = 1   */
      x4 = rand("Normal", 10);               /* mean=10; StdDev = 1 */
      output;
   end;
   c = 2;
   do i = 1 to &n2;
      x3 = rand("Exponential");              /* mean = StdDev = 1   */
      x4 = 10 * rand("Exponential");         /* mean = StdDev = 10  */
      output;
   end;
end;
run;

/* 2. Compute statistics */
%ODSOff 
proc ttest data=NND; 
  by SampleID; 
  class c; 
  var x3-x4; 
  ods output ttests=TTests(where=(method="Pooled")); 
run; 
%ODSOn

/* 3. Analyze sampling distribution of statistic */
/* 3a. Construct indicator var for tests that reject H0 at 0.05 significance */ 
data Results; 
  set TTests; 
  RejectH0 = (Probt <= 0.05); 
run; 

/* 3b. Compute proportion: (# that reject H0)/NumSamples */ 
proc sort data=Results; by Variable; run; 

proc freq data=Results; 
  by Variable; 
  tables RejectH0 / nocum; 
run;

/***********************************************************************/

%let n1 = 10;
%let n2 = 10;
%let NumSamples = 1e4;                /* number of samples */  

proc iml;
/* 1. Simulate the data by using RANDSEED and RANDGEN, */
call randseed(321);
x = j(&n1, &NumSamples);              /* allocate space for Group 1 */
y = j(&n2, &NumSamples);              /* allocate space for Group 2 */
call randgen(x, "Normal", 10);        /* fill matrix from N(0,10)   */
call randgen(y, "Exponential");       /* fill from Exp(1)           */
y = 10 * y;                           /* scale to Exp(10)           */

/* 2. Compute the t statistics; VAR operates on columns */
meanX = mean(x);  varX = var(x);      /* mean & var of each sample  */
meanY = mean(y);  varY = var(y);
/* compute pooled standard deviation from n1 and n2 */
poolStd = sqrt( ((&n1-1)*varX + (&n2-1)*varY)/(&n1+&n2-2) );

/* compute the t statistic */
t = (meanX - meanY) / (poolStd*sqrt(1/&n1 + 1/&n2));

/* 3. Construct indicator var for tests that reject H0 */ 
alpha = 0.05;
RejectH0 = (abs(t)>quantile("t", 1-alpha/2, &n1+&n2-2));  /* 0 or 1 */

/* 4. Compute proportion: (# that reject H0)/NumSamples */ 
Prob = RejectH0[:];
print Prob;
quit;

/********************************************************************
 Evaluating the Power of the t Test
 *******************************************************************/

proc power;
  twosamplemeans  power = .           /* missing ==> "compute this" */
    meandiff= 0 to 2 by 0.1           /* delta = 0, 0.1, ..., 2     */
    stddev=1                          /* N(delta, 1)                */
    ntotal=20;                        /* 20 obs in the two samples  */
  plot x=effect markers=none;
  ods output Output=Power;            /* output results to data set */
run;

/***********************************************************************/

%let n1 = 10;
%let n2 = 10;
%let NumSamples = 10000;               /* number of samples */  

data PowerSim(drop=i);
call streaminit(321);
do Delta = 0 to 2 by 0.1;
   do SampleID = 1 to &NumSamples;
      c = 1;
      do i = 1 to &n1;
         x1 = rand("Normal");
         output;
      end;
      c = 2;
      do i = 1 to &n2;
         x1 = rand("Normal", Delta, 1);
         output;
      end;
   end;
end;
run;

/* 2. Compute statistics */
%ODSOff 
proc ttest data=PowerSim; 
   by Delta SampleID; 
   class c; 
   var x1; 
   ods output ttests=TTests(where=(method="Pooled")); 
run; 
%ODSOn

/* 3. Analyze sampling distribution of statistic */
/* 3a. Construct indicator var for obs that reject H0 at 0.05 significance */ 
data Results; 
   set TTests; 
   RejectH0 = (Probt <= 0.05); 
run; 

/* 3b. Compute proportion: (# that reject H0)/NumSamples */ 
proc freq data=Results noprint; 
   by Delta; 
   tables RejectH0 / out=SimPower(where=(RejectH0=1));
run;

/* merge simulation estimates and values from PROC POWER */
data Combine;
   set SimPower Power;
   p = percent / 100;
   label p="Power";
run;

proc sgplot data=Combine noautolegend;
   title "Power of the t Test";
   title2 "Samples are N(0,1) and N(delta,1), n1=n2=10";
   series x=MeanDiff y=Power;
   scatter x=Delta y=p;
   xaxis label="Difference in Population Means (mu2 - mu1)";
run;

/**********************/
/* Answer to exercise */
/**********************/
proc freq data=Results noprint;
   by Delta;
   tables RejectH0 / nocum binomial(level='1');
   output out=Est binomial;
run;

data Combine;
   set Est Power;
run;

proc sgplot data=Combine noautolegend;
   series x=MeanDiff y=Power;
   scatter x=Delta y=_BIN_ / yerrorlower=L_Bin yerrorupper=U_Bin;
   yaxis min=0 max=1 label="Power (1 - P[Type II Error])" grid;
   xaxis label="Difference in Population Means (mu2 - mu1)" grid;
run;
/**********************/


/********************************************************************
 Effect of Sample Size on the Power of the t Test
 *******************************************************************/

/* The null hypothesis for the t test is H0: mu1 = mu2.
   Assume that mu2 = mu1 + delta.
   Find sample size N that rejects H0 80% of the time.  */
%let NumSamples = 1000;            /* number of samples */

data PowerSizeSim(drop=i Delta);
call streaminit(321);
Delta = 0.5;                       /* true difference between means */
do N =  40 to 100 by 5;            /* sample size                   */
   do SampleID = 1 to &NumSamples;
      do i = 1 to N;
         c = 1; x1 = rand("Normal");           output;
         c = 2; x1 = rand("Normal", Delta, 1); output;
      end;
   end;
end;
run;

/* 2. Compute statistics */
%ODSOff 
proc ttest data=PowerSizeSim; 
   by N SampleID; 
   class c; 
   var x1; 
   ods output ttests=TTests(where=(method="Pooled")); 
run; 
%ODSOn

/* 3. Construct indicator var for obs that reject H0 */ 
data ResultsSize; 
set TTests; 
RejectH0 = (Probt <= 0.05); 
run; 

proc freq data=ResultsSize noprint; 
   by N; 
   tables RejectH0 / out=SimPower(where=(RejectH0=1));
run;

proc power;
twosamplemeans
   meandiff = 0.5
   stddev = 1
   alpha = 0.05
   ntotal = 80 to 200 by 10
   power = .;
plot markers=none;
ods output Output=Power;
run;

data Combine;
set SimPower Power;
p = percent / 100;
NSamp = NTotal / 2;
run;

proc sgplot data=Combine noautolegend;
   title "Power of the t Test by Sample Size";
   title2 "Samples are N(0,1) and N(0.5,1), n1=n2=N";
   label N="Size of each sample"  p="Power";
   refline 0.8 / axis=y;
   series x=NSamp y=Power;
   scatter x=N y=p;
run;
title; title2;

/********************************************************************
 Using Simulation to Compute p-Values
 *******************************************************************/

proc iml;
Observed = {8 4 4 3 6 11};                       /* observed counts */
k = ncol(Observed);                              /*  6              */
N = sum(Observed);                               /* 36              */
p = j(1, k, 1/k);                                /* {1/6,...,1/6}   */
Expected = N*p;                                  /* {6,6,...,6}     */
qObs = sum( (Observed-Expected)##2/Expected );   /* q               */

/* simulate from null hypothesis */
NumSamples = 10000;
counts = RandMultinomial(NumSamples, N, p);      /* 10,000 samples  */
Q = ((counts-Expected)##2/Expected )[ ,+];       /* sum each row    */
pval = sum(Q>=qObs) / NumSamples;                /* proportion > q  */
print qObs pval;
call symputx("qObs", qObs);               /* create macro variables */
call symputx("pval", pval);
create chi2 var {Q}; append; close chi2;
quit;

proc sgplot data=chi2;
   title "Distribution of Test Statistic under Null Hypothesis";
   histogram Q / binstart=0 binwidth=1;
   refline &qObs / axis=x;
   inset "p-value = &pval";
   xaxis label="Test Statistic";
run;

/**********************/
/* Answer to exercise */
/**********************/
proc iml;
Observed = {8 4 4 3 6 11};                       /* observed counts */
k = ncol(Observed);                              /*  6              */
N = sum(Observed);                               /* 36              */
p = j(1, k, 1/k);                                /* {1/6,...,1/6}   */

NumSamples = 10000;
freq = RandMultinomial(NumSamples, N, p);        /* 10,000 samples  */
x = repeat(1:k, NumSamples);
SampleID = repeat(T(1:NumSamples), 1, k);
create die var {"SampleID" "Freq" "x"}; append; close;
quit;

proc freq data=die noprint;
  by SampleID;
  weight Freq;
  tables x / chisq;
  output out=chi2 chisq;
run;

proc sgplot data=chi2;
  title "Distribution of Test Statistic under Null Hypothesis";
  histogram _pchi_ / binstart=0 binwidth=1;
  refline 7.67 / axis=x;
  xaxis label="Test Statistic";
run;
/**********************/

