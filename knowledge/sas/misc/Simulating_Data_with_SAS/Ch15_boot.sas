/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 15: Resampling and Bootstrap Methods
 ***********************************************************************/

ods graphics on;

/********************************************************************
 Resampling Techniques in SAS Software
 *******************************************************************/

data Virginica(drop=Species);
set Sashelp.Iris(where=(Species="Virginica"));
run;

proc means data=Virginica nolabels Skew Kurt;
   var SepalLength;
run;

/********************************************************************
 Resampling with the DATA Step
 *******************************************************************/

%let MyData = Virginica;
%let NumSamples = 5000;

sasfile &MyData load;                                       /* 1    */
data BootDS(drop=i);
call streaminit(1);
do SampleID = 1 to &NumSamples;                             /* 2    */
   do i = 1 to NObs;                                        /* 4    */
      choice = ceil(NObs * rand("Uniform"));                /* 5    */ 
      set &MyData point=choice nobs=NObs;                   /* 3, 6 */
      output;
   end;
end;
STOP;                                                       /* 7    */
run;
sasfile &MyData close;                            /* release memory */

data _null_;
   call symput('N', NObs);
   if 0 then set &MyData nobs=NObs;
   STOP;
run;

%let VarName = SepalLength;
data BootArray(keep= SampleID &VarName);
array arr_y[&N] _temporary_;    

do i = 1 to NObs;                           /* read data one time   */
   set &MyData point=i nobs=NObs;           /* store obs in array   */
   arr_y[i] = &VarName;
end;

do SampleID = 1 to &NumSamples;             /* resampling algorithm */
   do i = 1 to NObs;
      choice=ceil(NObs * rand("Uniform")); 
      &VarName = arr_y[choice];             /* get value from array */
      output;
   end;
end;
STOP;
run;

/* compute bootstrap estimate on each bootstrap sample */
proc means data=BootDS noprint;
   by SampleID;
   var SepalLength;
   output out=OutStats skew=Skewness kurt=Kurtosis;
run;

proc sgplot data=OutStats;
   title "Bootstrap Estimates of Skewness and Kurtosis";
   scatter x=Skewness y=Kurtosis / transparency=0.7;
   refline 0.118 / axis=x;     /* reference line at observed values */
   refline 0.033 / axis=y;
   label Skewness= Kurtosis=;
run;

proc means data=OutStats nolabels N Mean StdDev P5 P95;
   var Skewness Kurtosis;
run;

proc univariate data=OutStats noprint;
   var Skewness Kurtosis;
   output out=Pctl95 pctlpts =2.5  97.5   pctlname=P025 P975
                  pctlpre =Skew_ Kurt_ mean=SkewMean KurtMean;
run;

proc print data=Pctl95 noobs; run;

/**********************/
/* Answer to exercise */
/**********************/
proc univariate data=OutStats noprint;
   var Skewness Kurtosis;
   histogram  Skewness Kurtosis;
run;
/**********************/

%let t0 = %sysfunc(datetime());
   /* put computation here */
%let t1 = %sysfunc(datetime());
%let elapsedTime = %sysevalf(&t1-&t0);

/********************************************************************
 Resampling with the SURVEYSELECT Procedure
 *******************************************************************/

%let MyData = Virginica;
%let NumSamples = 5000;
proc surveyselect data=&MyData NOPRINT seed=1       /* 1 */
     out=BootSS(rename=(Replicate=SampleID))        /* 2 */
     method=urs samprate=1                          /* 3 */
     reps=&NumSamples                               /* 4 */
     outhits;                                       /* 5 */
run;

proc means data=BootSS noprint;
   by SampleID;
   var SepalLength;
   output out=OutStats skew=Skewness kurt=Kurtosis;
run;

proc means data=OutStats nolabels N Mean StdDev P5 P95;
   var Skewness Kurtosis;
run;

/***********************************************************************/

proc surveyselect data=&MyData NOPRINT seed=1
     out=BootSSFreq(rename=(Replicate=SampleID))
     method=urs samprate=1 reps=&NumSamples;
run;

proc means data=BootSSFreq noprint;
   by SampleID;
   freq NumberHits;
   var SepalLength;
   output out=OutStats2 skew=Skewness kurt=Kurtosis;
run;

/********************************************************************
 Resampling Univariate Data with SAS/IML Software
 *******************************************************************/

proc iml;
/* Random sampling with replacement and uniform probability.
   Input: A is an input vector. 
   Output: (n x k) matrix of random values from A. */
start SampleReplace(A, n, k);
   r = j(n, k);                          /* allocate result matrix  */
   call randgen(r, "Uniform");           /* fill with random U(0,1) */
   r = ceil(nrow(A)*ncol(A)*r);          /* integers 1,2,...,ncol(A)*/
   return(shape(A[r], n));               /* reshape and return      */
finish;

start Skewness(X);
   /* Compute sample skewness for columns of X */
   n = countn(x, "col");
   c = x - mean(x);
   k2 = (c##2)[+,] / (n-1);              /* variance = k2           */
   k3 = (c##3)[+,] # n / ((n-1)#(n-2));
   skew = k3 / k2##1.5;
   return( skew );
finish;

start Kurtosis(X);
   /* Compute sample (excess) kurtosis for columns of X */
   n = countn(x, "col");
   c2 = (x - mean(x))##2;
   m2 = c2[+,]/n;       /* 2nd sample central moment of each column */
   m4 = (c2##2)[+,]/n;  /* 4th sample central moment                */

   k2 = m2 # n / (n-1);                 /* variance = k2            */
   k4 = n##2 /((n-1)#(n-2)#(n-3)) # ((n+1)#m4 - 3*(n-1)#m2##2);
   kurtosis = k4 / k2##2;               /* excess kurt = k4 / k2##2 */
   return( kurtosis );
finish;

store module=(SampleReplace Skewness Kurtosis);
quit;

%let MyData = Virginica;
%let NumSamples = 5000;

/* Basic bootstrap to explore variation of skewness and kurtosis */
proc iml;
call randseed(12345);
load module=(Skewness Kurtosis); /* load SampleReplace if necessary */
use &MyData;
read all var {SepalLength} into x;
close &MyData;

/* get all bootstrap resamples with a single call */
/*  s = SampleReplace(x, nrow(x), &NumSamples); */ /* prior to 12.1 */
s = sample(x, &NumSamples // nrow(x));      /* 50 x NumSamples      */
M = Skewness(s) // Kurtosis(s);             /* bootstrap statistics */
M = M`;                                     /* NumSamples x 2       */

means = mean(M);                /* summarize bootstrap distribution */ 
call qntl(q, M, {0.05 0.95});
s = means` || q`;
VarNames = {"Skewness" "Kurtosis"};
StatNames = {"Mean" "P5" "P95"};
print s[format = 9.5 r=VarNames c=StatNames];

/********************************************************************
 Resampling Multivariate Data with SAS/IML Software
 *******************************************************************/

/* compute sample correlations and Fisher 95% CI */
proc corr data=&MyData noprob fisher(biasadj=no);
   var SepalLength SepalWidth PetalLength;
   ods select FisherPearsonCorr;
run;

/* bootstrap of MV samples */
proc iml;
call randseed(12345);
use &MyData;
read all var {"SepalLength" "SepalWidth" "PetalLength"} into X;
close &MyData;

/* Resample from the rows of X. Generate the indices for 
   all bootstrap resamples with a single call */
N = nrow(X);
/* ndx = SampleReplace(1:N, &NumSamples, N); */
ndx = Sample(1:N, N // &NumSamples);        /* NumSamples x N       */

rho = j(&NumSamples, ncol(X));     /* allocate for results          */
do i = 1 to &NumSamples;
   rows = ndx[i, ];                /* selected rows for i_th sample */
   Y = X[rows, ];                  /* the i_th sample               */
   c = corr(Y);                    /* correlation matrix            */
   rho[i, ] = c[{2 3 6}]`;         /* upper triangular elements     */
end;

means = mean(rho);                 /* summarize bootstrap distrib   */ 
call qntl(q, rho, {0.025 0.975});
s = means` || q`;
varNames = {"p12" "p13" "p23"};
StatNames = {"Mean" "P025" "P975"};
print s[format = 9.5 r=VarNames c=StatNames];

/**********************/
/* Answer to exercise */
/**********************/
create Rho from rho[c=VarNames];
append from rho;
close;

ods graphics / antialiasmax=5000;
proc sgscatter data=rho;
   matrix p12 p13 p23 / transparency=0.8 diagonal=(histogram kernel);
run;
/**********************/


/********************************************************************
 The Parametric Bootstrap Method
 *******************************************************************/


/********************************************************************
 The Smooth Bootstrap Method
 *******************************************************************/

proc means data=BootSS noprint;
   by SampleID;
   var SepalLength;
   output out=OutMed median=Median;
run;

proc univariate data=OutMed;
   histogram Median / kernel;
   ods select histogram;
run;

%let MyData = Virginica;
%let VarName = SepalLength;
proc kde data=&MyData;
   univar SepalLength / method=SJPI unistats;
   ods select UnivariateStatistics;
run;

proc iml;
/* Smooth bootstrap.
   Input: A is an input vector with N elements.
   Output: (B x N) matrix. Each row is a sample. 
   Prior to SAS/IML 12.1, use the SampleReplace module */
start SmoothBootstrap(x, B, Bandwidth);
   N = nrow(x) * ncol(x);
   /* s = SampleReplace(x, B, N); */       /* prior to SAS/IML 12.1 */
   s = Sample(x, N // B);                        /* B x N matrix    */
   eps = j(B, N);                                /* allocate vector */
   call randgen(eps, "Normal", 0, Bandwidth);    /* fill vector     */
   return( s + eps );                            /* add random term */
finish;

use &MyData;  read all var {SepalLength} into x;  close &MyData;

call randseed(12345);
y = SmoothBootstrap(x, &NumSamples, 2.59);        /* SJPI bandwidth */
Median = Median(y`);                  /* smooth bootstrap estimates */
create Smooth var {"Median"}; append; close Smooth;
quit;

proc univariate data=Smooth;
   histogram Median / kernel;
   ods select histogram; 
run;

/**********************/
/* Answer to exercise */
/**********************/
data Smooth2;
set OutMed;
call streaminit(1);
Median = Median + rand("Normal", 0, 2.59);
run;

proc univariate data=Smooth2;
  histogram Median / kernel;
  ods select histogram;
run;
/**********************/

