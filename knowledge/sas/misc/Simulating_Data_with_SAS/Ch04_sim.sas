/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 4: Simulating Data to Estimate Sampling Distributions
 ***********************************************************************/


/********************************************************************
 Simulation by Using the DATA Step and SAS Procedures
 *******************************************************************/

%let N = 10;                           /* size of each sample */
%let NumSamples = 1000;                /* number of samples   */  
/* 1. Simulate data */
data SimUni;
call streaminit(123);
do SampleID = 1 to &NumSamples;
   do i = 1 to &N;
      x = rand("Uniform");
      output;
   end;
end;
run;

/* 2. Compute mean for each sample */
proc means data=SimUni noprint;
   by SampleID;
   var x;
   output out=OutStatsUni mean=SampleMean;
run;

/* 3. Analyze ASD: summarize and create histogram */
proc means data=OutStatsUni N Mean Std P5 P95;
   var SampleMean;
run;

ods graphics on;                              /* use ODS graphics   */
proc univariate data=OutStatsUni;
   label SampleMean = "Sample Mean of U(0,1) Data";
   histogram SampleMean / normal;             /* overlay normal fit */
   ods select Histogram;
run;

proc univariate data=OutStatsUni noprint;
   var SampleMean;
   output out=Pctl95 N=N mean=Mean pctlpts=2.5 97.5 pctlpre=Pctl;
run;

proc print data=Pctl95 noobs; 
run;

/***********************************************************************/

data Prob;
   set OutStatsUni;
   LargeMean = (SampleMean>0.7);       /* create indicator variable */
run;

proc freq data=Prob;
   tables LargeMean / nocum;           /* compute proportion        */
run;

proc format;
   value CutVal low-<0.7="less than 0.7"  0.7-high="greater than 0.7";
run;

/**********************/
/* Answer to exercise */
/**********************/
proc freq data=OutStatsUni;
   format SampleMean CutVal.;
   tables SampleMean / nocum;    /* compute proportion */
run;
/**********************/


/***********************************************************************/

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
run;

/* 2. Compute statistics for each sample */
proc means data=SimNormal noprint;
   by SampleID;
   var x;
   output out=OutStatsNorm mean=SampleMean median=SampleMedian var=SampleVar;
run;

/***********************************************************************/

/* variances of sampling distribution for mean and median */
proc means data=OutStatsNorm Var;
   var SampleMean SampleMedian;
run;

proc sgplot data=OutStatsNorm;
   title "Sampling Distributions of Mean and Median for N(0,1) Data";
   density SampleMean /   type=kernel legendlabel="Mean";
   density SampleMedian / type=kernel legendlabel="Median";
   refline 0 / axis=x;
run;

/***********************************************************************/

/* scale the sample variances by (N-1)/sigma^2 */
data OutStatsNorm;
   set OutStatsNorm;
   ScaledVar = SampleVar * (&N-1)/1; 
run;

/* Fit chi-square distribution to data */
proc univariate data=OutStatsNorm;
   label ScaledVar = "Variance of Normal Data (Scaled)";
   histogram ScaledVar / gamma(alpha=15 sigma=2);   /* = chi-square */
   ods select Histogram;
run;

/***********************************************************************/

%let NumSamples = 1000;                /* number of samples */
/* 1. Simulate data */
data SimUniSize;
call streaminit(123);
do N = 10, 30, 50, 100;
   do SampleID = 1 to &NumSamples;
      do i = 1 to N;
         x = rand("Uniform");
         output;
      end;
   end;
end;
run;

/* 2. Compute mean for each sample */
proc means data=SimUniSize noprint;
   by N SampleID;
   var x;
   output out=OutStats mean=SampleMean;
run;

/* 3. Summarize approx. sampling distribution of statistic */
proc means data=OutStats Mean Std;
   class N;
   var SampleMean;
run;

proc means data=OutStats noprint;
  class N;
  var SampleMean;
  output out=out(where=(_TYPE_=1)) Mean=Mean Std=Std;
run;

proc iml;
use out;
read all var {N Mean Std};
close out;

NN = N;
x = T( do(0.1, 0.9, 0.0025) );
create Convergence var {N x pdf};

do i = 1 to nrow(NN);
   N = j(nrow(x), 1, NN[i]);
   pdf = pdf("Normal", x, Mean[i], Std[i]);
   append;
end;

close Convergence;
quit;

ods graphics / ANTIALIASMAX=1300;
proc sgplot data=Convergence;
   title "Sampling Distribution of Sample Mean";
   label pdf = "Density"
	 N = "Sample Size";
   series x=x y=pdf / group=N;
run;

/**********************/
/* Answer to exercise */
/**********************/
/* Partial solution. Generate data and use the following: */
/*
proc means data=OutStats noprint;
   class N;
   var SampleMean;
   output out=stderr std=s;
run;

proc sgplot data=stderr;
   series x=N y=s;
   yaxis min=0;
run;
*/
/**********************/


/***********************************************************************/

/* bias of kurtosis in small samples */
%let N = 50;                         /* size of each sample */
%let NumSamples = 1000;              /* number of samples   */  
data SimSK(drop=i);
call streaminit(123);
do SampleID = 1 to &NumSamples;      /* simulation loop             */
   do i = 1 to &N;                   /* N obs in each sample        */
      Normal      = rand("Normal");  /* kurt=0                      */
      t           = rand("t", 5);    /* kurt=6 for t, exp, and logn */
      Exponential = rand("Expo");
      LogNormal   = exp(rand("Normal", 0, 0.503)); 
      output;
   end;
end;
run;

proc means data=SimSK noprint;
   by SampleID;
   var Normal t Exponential LogNormal;
   output out=Moments(drop=_type_ _freq_) Kurtosis=;
run;

proc transpose data=Moments out=Long(rename=(col1=Kurtosis));
   by SampleID;
run;

proc sgplot data=Long;
   title "Kurtosis Bias in Small Samples: N=&N";
   label _Name_ = "Distribution";
   vbox Kurtosis / category=_Name_ meanattrs=(symbol=Diamond);
   refline 0 6 / axis=y;
   yaxis max=30;
   xaxis discreteorder=DATA;
run;

/********************************************************************
 Simulating Data by Using the SAS/IML Language
 *******************************************************************/

%let N = 10;
%let NumSamples = 1000;
proc iml;
call randseed(123);
x = j(&NumSamples,&N);       /* many samples (rows), each of size N */
call randgen(x, "Uniform");  /* 1. Simulate data                    */
s = x[,:];                   /* 2. Compute statistic for each row   */
Mean = mean(s);              /* 3. Summarize and analyze ASD        */
StdDev = std(s);
call qntl(q, s, {0.05 0.95});
print Mean StdDev (q`)[colname={"5th Pctl" "95th Pctl"}];

/* compute proportion of statistics greater than 0.7 */
Prob = mean(s > 0.7);
print Prob[format=percent7.2];

/**********************/
/* Answer to exercise */
/**********************/
proc iml;
call randseed(123);
x = j(10000, 10);
call randgen(x, "Uniform");  * 1. Simulate data;
s = x[,<>];                  * 2. Compute statistic for each row;
Mean = mean(s);              * 3. Summarize and analyze ASD;
StdDev = std(s);
call qntl(q, s, {0.05 0.95});
print Mean StdDev (q`)[colname={"5th Pctl" "95th Pctl"}];
create MaxDist var {s}; append; close MaxDist;

proc univariate data=MaxDist(rename=(s=Max));
   label Max = "Maximum of Uniform Sample, N=10";
   histogram Max;
   ods select Histogram;
run;   
/**********************/


/***********************************************************************/

proc iml;
call randseed(123);
x = j(&NumSamples,&N);       /* many samples (rows), each of size N */
/* "long" format: first generate data IN ROWS... */
call randgen(x, "Uniform");       /* 1. Simulate data (all samples) */
ID = repeat( T(1:&NumSamples), 1, &N); /* {1   1 ...   1,
                                           2   2 ...   2,
                                         ... ... ... ...
                                         100 100 ... 100} */
/* ...then convert to long vectors and write to SAS data set */
SampleID = shape(ID, 0, 1);     /* 1 col, as many rows as necessary */
z = shape(x, 0, 1);
create Long var{SampleID z}; append; close Long;
create Long2 var{ID x}; append; close Long2;

/***********************************************************************/

%let N = 20;                      /* size of each sample */
%let NumSamples = 1000;           /* number of samples   */  
proc iml;
call randseed(123);
mu = {0 0}; Sigma = {1 0.3, 0.3 1};
rho = j(&NumSamples, 1);          /* allocate vector for results    */
do i = 1 to &NumSamples;          /* simulation loop                */
   x = RandNormal(&N, mu, Sigma); /* simulated data in N x 2 matrix */
   rho[i] = corr(x)[1,2];         /* Pearson correlation            */
end;
/* compute quantiles of ASD; print with labels */
call qntl(q, rho, {0.05 0.25 0.5 0.75 0.95});
print (q`)[colname={"P5" "P25" "Median" "P75" "P95"}];
create corr var {"Rho"}; append; close;       /* write ASD */
quit;
/* 3. Visualize approx. sampling distribution of statistic */
ods graphics on;
proc univariate data=Corr;
   label Rho = "Pearson Correlation Coefficient";
   histogram Rho / kernel;
   ods select Histogram;
run;

/**********************/
/* Answer to exercise */
/**********************/
data ProbCorr;
set corr;
t = (Rho < 0);
run;

ods graphics off;
proc freq data=ProbCorr;
   tables t;
run;
/**********************/

