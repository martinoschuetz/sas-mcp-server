/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 3: Preliminary and Background Information
 ***********************************************************************/


/********************************************************************
 Essential Functions for Working with Statistical Distributions
 *******************************************************************/


/***********************************************************************/

data pdf;
do x = -3 to 3 by 0.1;
   y = pdf("Normal", x);
   output;
end;
   x0 = 0; pdf0 = pdf("Normal", x0); output;
   x0 = 1; pdf0 = pdf("Normal", x0); output;
run;

proc sgplot data=pdf noautolegend;
   series x=x y=y;
   scatter x=x0 y=pdf0;
   vector x=x0 y=pdf0 /xorigin=x0 yorigin=0 noarrowheads lineattrs=(color=gray);
   xaxis grid label="x"; yaxis grid label="Normal PDF";
   refline 0 / axis=y;
run;

/***********************************************************************/

data cdf;
do x = -3 to 3 by 0.1;
   y = cdf("Normal", x);
   output;
end;
   x0 = 0;     cdf0 = cdf("Normal", x0); output;
   x0 = 1.645; cdf0 = cdf("Normal", x0); output;
run;

ods graphics / height=500;
proc sgplot data=cdf noautolegend;
   series x=x y=y;
   scatter x=x0 y=cdf0;
   vector x=x0 y=cdf0 /xorigin=x0 yorigin=0 noarrowheads lineattrs=(color=gray);
   vector x=x0 y=cdf0 /xorigin=-3 yorigin=cdf0 noarrowheads lineattrs=(color=gray);
   xaxis grid label="x";
   yaxis grid label="Normal CDF" values=(0 to 1 by 0.05);
   refline 0 1/ axis=y;
run;
ods graphics / reset;

/***********************************************************************/


/********************************************************************
 Random Number Streams in SAS
 *******************************************************************/
 

/***********************************************************************/

data a;
call streaminit(4321); 
do i = 1 to 10;  x=rand("uniform"); output;  end;
run;

data b;
call streaminit(4321); 
do i = 1 to 10;  x=rand("uniform"); output;  end;
run;

proc compare base=a compare=b; run;      /* show they are identical */

/***********************************************************************/

data a;
call streaminit(0);                   /* different stream each time */
do i = 1 to 10;  x=rand("uniform"); output;  end;
run;

data b;
call streaminit(&sysrandom);      /* use SYSRANDOM to set same seed */
do i = 1 to 10;  x=rand("uniform"); output;  end;
run;

proc compare base=a compare=b short;     /* show they are identical */
run;

/********************************************************************
 Checking the Correctness of Simulated Data
 *******************************************************************/


/***********************************************************************/

%let N=500;
data Gamma(keep=x);
call streaminit(4321);
do i = 1 to &N;
   x = rand("Gamma", 4);               /* shape=4, unit scale */
   output;
end;
run;

/* fit Gamma distrib to data; compute GOF tests */
proc univariate data=Gamma;
   var x;
   histogram x / gamma(alpha=EST scale=1); 
   ods select Moments ParameterEstimates GoodnessOfFit;
run;

/***********************************************************************/

%let N=100;
data Geometric(keep=x);
call streaminit(4321);
do i = 1 to &N;
   x = rand("Geometric", 0.5);      /* number of tosses until heads */
   output;
end;
run;

/* For the geometric distribution, PDF("Geometric",t,0.5) computes the 
   probability of t FAILURES, t=0,1,2,...  Use PDF("Geometric",t-1,0.5) 
   to compute the number of TOSSES until heads appears, t=1,2,3,.... */
data PMF(keep=T Y);
do T = 1 to 9;
   Y = pdf("Geometric", T-1, 0.5);
   output;
end;
run;

data Discrete;
   merge Geometric PMF;
run;

/* GTL syntax changed at 9.4 */
%macro ScaleOpt;
   %if %sysevalf(&SysVer < 9.4) %then pct;  %else proportion;
%mend;

proc template;
define statgraph BarPMF;
dynamic _Title;                        /* specify title at run time */
begingraph;
   entrytitle _Title;
   layout overlay / yaxisopts=(griddisplay=on)
                    xaxisopts=(type=discrete);
   barchart    x=X / name='bar' legendlabel='Sample' stat=%ScaleOpt;
   scatterplot x=T y=Y / name='pmf' legendlabel='PMF';
   discretelegend 'bar' 'pmf';
   endlayout;
endgraph;
end;
run;

proc sgrender data=Discrete template=BarPMF;
   dynamic _Title = "Sample from Geometric(0.5) Distribution (N=&N)";
run;


/**********************/
/* Answer to exercise */
/**********************/
%let N = 100;
data NegBin(keep=x);
call streaminit(0);
do i = 1 to &N;
   x = rand("NegBin", 0.5, 3);
   output;
end;
run;

data PMF(keep=T Y);
do T = 0 to 15;
   Y = pdf("NegBin", T, 0.5, 3);
   output;
end;
run;

data Discrete;
merge NegBin PMF;
run;

proc sgrender data=Discrete template=BarPMF;
   dynamic _Title = "Sample from NegBin(0.5,3) Distribution (N=&N)";
run;
/**********************/


/***********************************************************************/

data PDF(keep=T Y);
do T = 0 to 13 by 0.1;
   Y = pdf("Gamma", T, 4);
   output;
end;
run;

data Cont;
   merge Gamma PDF;
run;

proc template;
define statgraph HistPDF;
dynamic _Title _binstart _binstop _binwidth;
begingraph;
   entrytitle _Title;
   layout overlay / xaxisopts=(linearopts=(viewmax=_binstop));
   histogram X / scale=density endlabels=true xvalues=leftpoints 
         binstart=_binstart binwidth=_binwidth;
   seriesplot x=T y=Y / name='PDF' legendlabel="PDF" 
         lineattrs=(thickness=2);
   discretelegend 'PDF';
   endlayout;
endgraph;
end;
run;

proc sgrender data=Cont template=HistPDF;
dynamic _Title="Sample from Gamma(4) Distribution (N=&N)"
   _binstart=0                        /* left endpoint of first bin */
   _binstop=13                        /* right endpoint of last bin */
   _binwidth=1;                       /* width of bins              */
run;

/***********************************************************************/

data Exponential(keep=x);
call streaminit(4321);
sigma = 10;
do i = 1 to &N;
   x = sigma * rand("Exponential");
   output;
end;
run;

/* create an exponential Q-Q plot */
proc univariate data=Exponential;
   var x;
   qqplot x / exp;
run;

%let N = 100;
data Normal(keep=x);
call streaminit(4321);
do i = 1 to &N;
   x = rand("Normal");                         /* N(0, 1) */
   output;
end;
run;

/* Manually create a Q-Q plot */
proc sort data=Normal out=QQ; by x; run;             /* 1 */

data QQ;
set QQ nobs=NObs;
v = (_N_ - 0.375) / (NObs + 0.25);                   /* 2 */
q = quantile("Normal", v);                           /* 3 */
label x = "Observed Data" q = "Normal Quantiles";
run;

proc sgplot data=QQ;                                 /* 4 */
   scatter x=q y=x;
   xaxis grid;  yaxis grid;
run;

/********************************************************************
 Using ODS Statements to Control Output
 *******************************************************************/

ods trace on;
ods graphics off;
proc freq data=Sashelp.Class;
   tables sex / chisq;
run;
ods trace off;

ods select OneWayChiSq;;
ods exclude OneWayFreqs;
proc freq data=Sashelp.Class;
   tables sex;
   ods output OneWayFreqs=Freqs;
run;

proc contents data=Freqs short order=varnum; 
run;

ods graphics on;
proc freq data=Sashelp.Class;
   tables age / plot=FreqPlot;
   ods select FreqPlot;
run;
