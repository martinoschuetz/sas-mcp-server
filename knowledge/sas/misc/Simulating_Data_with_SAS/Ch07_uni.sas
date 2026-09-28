/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 7: Advanced Simulation of Univariate Data
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
 Adding Location and Scale Parameters
 *******************************************************************/


/**********************/
/* Answer to exercise */
/**********************/
data Expon;
call streaminit(123);
do i = 1 to 1000;
   x=2*rand("expo");
   output;
end;
run;

ods graphics on;
proc univariate data=Expon;
   var x;
   histogram x/exponential(sigma=2) midpoints=(0.5 to 15);
   ods select BasicMeasures Histogram;
run;
/**********************/


/********************************************************************
 Simulating from Less Common Univariate Distributions
 *******************************************************************/

/* Simulate from inverse Gaussian (Devroye, p. 149) */
data InvGauss(keep= X);
mu = 1.5;                             /* mu > 0     */
lambda = 2;                           /* lambda > 0 */
c = mu/(2 * lambda);
call streaminit(1);
do i = 1 to 1000;
   muY = mu * rand("Normal")**2;      /* or mu*rand("ChiSquare", 1) */
   X = mu + c*muY - c*sqrt(4*lambda*muY + muY**2);
   /* return X with probability mu/(mu+X); otherwise mu**2/X */
   if rand("Uniform") > mu/(mu+X) then /* or rand("Bern", X/(mu+X)) */
      X = mu*mu/X;
   output;
end;
run;

/***********************************************************************/

/* Simulate from Pareto (Devroye, p. 29) */
data Pareto(keep= X);
a = 4;                    /* alpha > 0                              */
k = 1.5;                  /* scale > 0 determines lower limit for x */
call streaminit(1);
do i = 1 to 1000;
   U = rand("Uniform");
   X = k / U**(1/a);
   output;
end;
run;

/***********************************************************************/

/* Johnson SB(threshold=theta, scale=sigma, shape=delta, shape=gamma) */
data SB(keep= X);
call streaminit(1);
theta = -0.6;   scale = 18;   delta = 1.7;    gamma = 2;
do i = 1 to 1000;
   Y = (rand("Normal")-gamma) / delta;
   expY = exp(Y);
   /* if theta=0 and sigma=1, then X = logistic(Y) */
   X = ( sigma*expY + theta*(expY + 1) ) / (expY + 1);
   output;
end;
run;

/***********************************************************************/

/* Johnson SU(threshold=theta, scale=sigma, shape=delta, shape=gamma) */
data SU(keep= X);
call streaminit(1);
theta = 1;  sigma = 5;   delta = 1.5;  gamma = -1;
do i = 1 to 10000;
   Y = (rand("Normal")-gamma) / delta;
   X = theta + sigma * sinh(Y);
   output;
end;
run;

proc univariate data=SU;
   histogram x / su noplot;
   ods select ParameterEstimates;
run;

/**********************/
/* Answer to exercise */
/**********************/
/* Johnson SU(threshold=theta, scale=sigma, shape=delta, shape=gamma) */
/*
data SUSamples(keep= SampleID X);
call streaminit(1);
theta = 1;  sigma = 5;   delta = 1.5;  gamma = -1;
do SampleID = 1 to 1000;
   do i = 1 to 100;
      Y = (rand("Normal")-gamma) / delta;
      X = theta + sigma * sinh(Y);
      output;
   end;
end;
run;

%ODSOff
proc univariate data=SUSamples;
   by SampleID;
   histogram X / noplot SU(theta=est sigma=est);
   ods output ParameterEstimates=PE(where=(Symbol^=" "));
run;
%ODSOn

proc univariate data=PE;
   class Symbol;
   histogram Estimate;
   ods select Histogram;
run;

proc means data=PE mean std p5 p95 min max;
   class Symbol;
   var Estimate;
run;
*/
/**********************/


/********************************************************************
 Inverse CDF Sampling
 *******************************************************************/

/* Inverse CDF algorithm */
%let N = 100;                          /* size of sample */
data Exp(keep=x);
call streaminit(12345);
do i = 1 to &N;
   u = rand("Uniform");
   x = -log(1-u);
   output;
end;
run;

proc univariate data=Exp;
   histogram x / exponential(sigma=1) endpoints=0 to 6 by 0.5;
   cdfplot x / exponential(sigma=1);
   ods select GoodnessOfFit Histogram CDFPlot; 
run; 

/***********************************************************************/

proc iml;
/* a quantile is a zero of the following function */
start Func(x) global(target);
   cdf = (x + x##3 + x##5)/3;
   return( cdf-target );
finish;

/* test bisection module */
target = 0.5;                /* global variable used by Func module */
/* for SAS/IML 9.3 and before, use q = Bisection(0,1); */ 
q = froot("Func", {0 1});    /* SAS/IML 12.1                        */
p = (q + q##3 + q##5)/3;     /* check whether F(q) = target         */
print q p[label="CDF(q)"];  
N = 100;
call randseed(12345);
u = j(N,1); x = j(N,1);
call randgen(u, "Uniform");             /* u ~ U(0,1)        */
do i = 1 to N;
   target = u[i];
   /* for SAS/IML 9.3 and before, use x[i] = Bisection(0,1); */ 
   x[i] = froot("Func", {0 1});         /* SAS/IML 12.1      */
end;
create Poly var {"x"}; append; close Poly;
quit;

ods graphics on;
proc univariate data=Poly;
   histogram x / endpoints=0 to 1 by 0.1;
   cdfplot x;
   ods select Histogram CDFPlot;
run;

/********************************************************************
 Finite Mixture Distributions
 *******************************************************************/

%let N = 100;                                 /* size of sample     */
data Calls(drop=i);
call streaminit(12345);
array prob [3] _temporary_ (0.5 0.3 0.2);
do i = 1 to &N;
   type = rand("Table", of prob[*]);          /* returns 1, 2, or 3 */
   if type=1 then      x = rand("Normal",  3, 1);   
   else if type=2 then x = rand("Normal",  8, 2);
   else                x = rand("Normal", 10, 3);              
   output;
end;
run;

proc univariate data=Calls;
   ods select Histogram;
   histogram x / vscale=proportion
   kernel(lower=0 c=SJPI);              
run;

/***********************************************************************/

%let std = 10;                        /* magnitude of contamination */
%let N = 100;                         /* size of sample             */
data CN(keep=x);
call streaminit(12345);
do i = 1 to &N;
   if rand("Bernoulli", 0.1) then 
      x = rand("Normal", 0, &std);
   else 
      x = rand("Normal");
   output;
end;
run;

proc univariate data=CN;
   var x;
   histogram x / kernel vscale=proportion endpoints=-15 to 21 by 1;
   qqplot x;
run;

/**********************/
/* Answer to exercise */
/**********************/
/* Generate a continuous mixture distribution:
   X ~ N(mu, 1) where mu~U(0,1) */
data ContMix(keep=x);
call streaminit(12345);
do i = 1 to 10000;
   mu = rand("Uniform");               /* mu ~ U(0,1)  */
   x = rand("Normal", mu);             /* x ~ N(mu, 1) */
   output;
end;
run;

proc univariate data=ContMix;
   var x; histogram x / normal;
run;
/**********************/


/********************************************************************
 Simulating Survival Data
 *******************************************************************/

/* sigma is scale parameter; use sigma=1/lambda for a rate parameter */
%macro RandExp(sigma);
   ((&sigma) * rand("Exponential"))
%mend;

data LifeData;
call streaminit(1);
do PatientID = 1 to 100;
   t = %RandExp(1/0.01);               /* hazard rate = 0.01 */
   output;
end;
run;

proc lifetest data=LifeData;
   time t;
   ods select Quartiles Means;
run;

data CensoredData(keep= PatientID t Censored);
call streaminit(1);
HazardRate = 0.01;         /* rate at which subject experiences event */
CensorRate = 0.001;        /* rate at which subject drops out         */
EndTime = 365;             /* end of study period                     */
do PatientID = 1 to 100;
   tEvent = %RandExp(1/HazardRate);
   c = %RandExp(1/CensorRate);
   t = min(tEvent, c, EndTime);
   Censored = (c < tEvent | tEvent > EndTime);
   output;
end;
run;

proc lifetest data=CensoredData plots=(survival(atrisk CL));
   time t*Censored(1);
   ods select Quartiles Means CensoredSummary SurvivalPlot;
run;

/********************************************************************
 The Acceptance-Rejection Technique
 *******************************************************************/

%let N = 100;                          /* size of sample */
data TruncNormal(keep=x);
call streaminit(12345);
a = 0;
do i = 1 to &N;
   do until( x>=a );                   /* reject x < a   */
      x = rand("Normal");
   end;
   output;
end;
run;

proc iml;
call randseed(12345);
multiple = 2.5;                   /* choose value > 2               */
y = j(multiple * &N, 1);          /* allocate more than you need    */
call randgen(y, "Normal");        /* y ~ N(0,1)                     */
idx = loc(y > 0);                 /* acceptance step                */
x = y[idx];
x = x[1:&N];                      /* discard any extra observations */
p = 0.5;                  /* prob of accepting instrumental variate */
F = quantile("NegBin", 0.999, p, &N); 
M = F + &N;               /* Num Trials = failures + successes      */
print M;

/**********************/
/* Answer to exercise */
/**********************/
proc iml;
call randseed(12345);
N = 248;
NumSamples = 10000;
y = j(NumSamples, N);             /* allocate more than you need    */
call randgen(y, "Normal");        /* y ~ N(0,1)                     */
idx = loc(y < 0);                 /* rejection step                 */
y[idx] = .;                       /* replace neg vals with missing  */
c = countn(y, "row");             /* count nonmissing in each row   */
m = mean(c>= 100);                /* proportion for which more than */
print m;                          /*     100 obs were accepted      */
quit;
/**********************/

