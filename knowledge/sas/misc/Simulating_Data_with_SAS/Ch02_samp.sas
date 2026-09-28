/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 2: Simulating Data from Common Univariate Distributions
 ***********************************************************************/

ods graphics on;

/********************************************************************
 Getting Started: Simulate Data from the Standard Normal Distribution
 *******************************************************************/

data Normal(keep=x);
call streaminit(4321);               /* Step 1 */
do i = 1 to 100;                     /* Step 2 */
   x = rand("Normal");               /* Step 3 */
   output;
end;
run;

proc print data=Normal(obs=5); 
run;

/********************************************************************
 Simulating Data from Discrete Distributions
 *******************************************************************/

/* GTL syntax changed at 9.4 */
%macro ScaleOpt;
%if %sysevalf(&SysVer < 9.4) %then pct;
%else proportion;
%mend;

proc template;
define statgraph DiscretePDF;
dynamic _X _T _Y _Title _HAlign;
begingraph;
   entrytitle halign=center _Title;
   layout overlay / yaxisopts=(griddisplay=on)
           xaxisopts=(type=discrete display=(TICKS TICKVALUES LINE ));
   barchart x=_X / name='bar' stat=%ScaleOpt legendlabel='Sample';
   scatterplot x=_T y=_Y / name='pmf' legendlabel='PMF'
        markerattrs=GraphDataDefault(symbol=CIRCLEFILLED size=10);
   discretelegend 'bar' 'pmf' / opaque=true border=true halign=_HAlign 
        valign=top across=1 location=inside;
   endlayout;
endgraph;
end;
run;

title; title2; title3;
%macro MergeAndPlot(DistName);
   data Discrete;
   merge &DistName PMF;
   run;

   proc sgrender data=Discrete template=DiscretePDF;
      dynamic _X="X" _T="T" _Y="Y" _HAlign="right"
      _Title="Sample from &DistName Distribution (N=&N)";
   run;
%mend;

/***********************************************************************/

%let N = 100;
data Bernoulli(keep=x);
call streaminit(4321);
p = 1/2;
do i = 1 to &N;
   x = rand("Bernoulli", p);           /* coin toss */
   output;
end;
run;

data PMF(keep=t Y);
p = 1/2;
do t = 0 to 1;
   Y = pdf("Bernoulli", t, p);
   output;
end;
run;

%MergeAndPlot(Bernoulli)

/***********************************************************************/

data Binomial(keep=x);
call streaminit(4321);
p = 1/2;
do i = 1 to &N;
   x = rand("Binomial", p, 10);     /* number of heads in 10 tosses */
   output;
end;
run;

data PMF(keep=t Y);
p = 1/2;
do t = 0 to 10;
   Y = pdf("Binomial", t, p, 10);
   output;
end;
run;

%MergeAndPlot(Binomial)

/***********************************************************************/


/**********************/
/* Answer to exercise */
/**********************/
data Geometric(keep=x);
call streaminit(4321);
p = 1/2;
do i = 1 to 100;
   x = rand("Geometric", p);      /* number of trials until success */
   output;
end;
run;
/**********************/


/***********************************************************************/

data Uniform(keep=x);
call streaminit(4321);
k = 6;                                   /* a six-sided die         */
do i = 1 to &N;
   x = ceil(k * rand("Uniform"));        /* roll 1 die with k sides */
   output;
end;
run;

proc freq data=Uniform;
   tables x / nocum;
run;

/***********************************************************************/

data Table(keep=x);
call streaminit(4321);
p1 = 0.5; p2 = 0.2; p3 = 0.3;
do i = 1 to &N;
   x = rand("Table", p1, p2, p3);        /* sample with replacement */
   output;
end;
run;

proc freq data=Table;
   tables x / nocum;
run;

data Table(keep=x);
call streaminit(4321);
array p[3] _temporary_ (0.5 0.2 0.3);
do i = 1 to &N;
   x = rand("Table", of p[*]);           /* sample with replacement */
   output;
end;
run;

/**********************/
/* Answer to exercise */
/**********************/
data TossDie(keep=x);
call streaminit(4321);
array p[6] _temporary_ (0.16667 0.16667 0.16667 0.16667 0.16667 0.16667);
do i = 1 to 1000;
   x = rand("Table", of p[*]); 
   output;
end;
run;
/**********************/


/***********************************************************************/

data Poisson(keep=x);
call streaminit(4321);
lambda = 4;
do i = 1 to &N;
   x = rand("Poisson", lambda);         /* num events per unit time */
   output;
end;
run;

data PMF(keep=t Y);
lambda = 4;
do t = 0 to 10;
   Y = pdf("Poisson", t, lambda);
   output;
end;
run;

%MergeAndPlot(Poisson)

/**********************/
/* Answer to exercise */
/**********************/
data NegBin(keep=x);
call streaminit(4321);
do i = 1 to 1000;
   x = rand("NegBin", 1/6, 3); 
   output;
end;
run;

proc univariate data=NegBin;
   histogram x;
   ods select histogram;
run;
/**********************/


/********************************************************************
 Simulating Data from Continuous Distributions
 *******************************************************************/

proc template;
define statgraph ContPDF;
dynamic _X _T _Y _Title _HAlign
        _binstart _binstop _binwidth;
begingraph;
   entrytitle halign=center _Title;
   layout overlay /xaxisopts=(linearopts=(viewmax=_binstop));
      histogram _X / name='hist' SCALE=DENSITY binaxis=true 
         endlabels=true xvalues=leftpoints binstart=_binstart binwidth=_binwidth;
      seriesplot x=_T y=_Y / name='PDF' legendlabel="PDF" lineattrs=(thickness=2);
      discretelegend 'PDF' / opaque=true border=true halign=_HAlign valign=top 
            across=1 location=inside;
   endlayout;
endgraph;
end;
run;

%macro ContPlot(DistName, binstart, binstop, binwidth);
   data Cont;
   merge &DistName PDF;
   run;

   proc sgrender data=Cont template=ContPDF;
   dynamic _X="X" _T="T" _Y="Y" _HAlign="right"
	   _binstart=&binstart _binstop=&binstop _binwidth=&binwidth
	   _Title="Sample from &DistName Distribution (N=&N)";
   run;
%mend;

/***********************************************************************/

%let N = 100;
data Normal(keep=x);
call streaminit(4321);
do i = 1 to &N;
   x = rand("Normal");                 /* X ~ N(0, 1) */
   output;
end;
run;

data PDF;
do t = -3.5 to 3.5 by 0.05;
   Y = pdf("Normal", t);
   output;
end;
run;

%ContPlot(Normal,-3.5,3.5,0.5)

/***********************************************************************/


/**********************/
/* Answer to exercise */
/**********************/
data Uni(keep=x);
call streaminit(4321);
do i = 1 to &N;
   x = -1 + 2*rand("Uniform");         /* X ~ U(-1, 1) */
   output;
end;
run;
/**********************/


/***********************************************************************/

data Exponential(keep=x);
call streaminit(4321);
sigma = 10;
do i = 1 to &N;
   x = sigma * rand("Exponential");    /* X ~ Expo(10) */
   output;
end;
run;

data PDF;
do t = 1 to 45;
   Y = pdf("Exponential", t, 10);
   output;
end;
run;

%ContPlot(Exponential, 0.0, 45, 5);

/********************************************************************
 Simulating Univariate Data in SAS/IML Software
 *******************************************************************/


/***********************************************************************/

proc iml;
/* define parameters */
p = 1/2;  lambda = 4;  k = 6;  prob = {0.5 0.2 0.3};

/* allocate vectors */
N = 100;
Bern = j(1, N);   Bino = j(1, N);   Geom = j(1, N);
Pois = j(1, N);   Unif = j(1, N);   Tabl = j(1, N);

/* fill vectors with random values */
call randseed(4321);
call randgen(Bern, "Bernoulli", p);     /* coin toss                */
call randgen(Bino, "Binomial", p, 10);  /* num heads in 10 tosses   */
call randgen(Geom, "Geometric", p);     /* num trials until success */
call randgen(Pois, "Poisson", lambda);  /* num events per unit time */
call randgen(Unif, "Uniform");          /* uniform in (0,1)         */
Unif = ceil(k * Unif);                  /* roll die with k sides    */
call randgen(Tabl, "Table", prob);      /* sample with replacement  */
quit;

proc iml;
call randseed(4321);
prob = j(6, 1, 1)/6;                /* equal prob. for six outcomes */
d = j(1, &N);                       /* allocate 1 x N vector        */
call randgen(d, "Table", prob);     /* fill with integers in 1-6    */
quit;

/***********************************************************************/

proc iml;
call randseed(4321);
socks = {"Black" "Black" "Black" "Black" "Black" 
         "Brown" "Brown" "White" "White" "White"};
params = { 5,                         /* sample size                */
           3 };                       /* number of samples          */  
s = sample(socks, params, "WOR");     /* sample without replacement */
print s;
quit;

/***********************************************************************/

proc iml;
/* define parameters */
mu = 3;  sigma = 2;

/* allocate vectors */
N = 100;
StdNor = j(1, N);  Normal = j(1, N);
Unif = j(1, N);    Expo   = j(1, N);

/* fill vectors with random values */
call randseed(4321);
call randgen(StdNor, "Normal");               /* N(0,1)      */
call randgen(Normal, "Normal", mu, sigma);    /* N(mu,sigma) */
call randgen(Unif,   "Uniform");              /* U(0,1)      */
call randgen(Expo,   "Exponential");          /* Exp(1)      */
quit;

