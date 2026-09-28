/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 8: Simulating Data from Basic Multivariate Distributions
 ***********************************************************************/


/********************************************************************
 The Multinomial Distribution
 *******************************************************************/

%let N = 1000;                      /* size of each sample          */
proc iml;
call randseed(4321);                /* set seed for RandMultinomial */
prob = {0.5 0.2 0.3};
X = RandMultinomial(&N, 100, prob);     /* one sample, N x 3 matrix */

/* print a few results */
c = {"black", "brown", "white"};
first = X[1:5,];
print first[colname=c label="First 5 Obs: Multinomial"];
mean = mean(X);
std = std(X);
corr = corr(X);
print mean[colname=c], 
      std[colname=c], 
      corr[colname=c rowname=c format=BEST5.];
/* write multinomial data to SAS data set */
create MN from X[c=c]; append from X; close MN;
quit;

ods graphics on;
proc kde data=MN;
   bivar black brown / plots=ContourScatter;
run;

/********************************************************************
 Multivariate Normal Distributions
 *******************************************************************/

%let N = 1000;                               /* size of each sample */

/* Multivariate normal data */
proc iml;
/* specify the mean and covariance of the population */
Mean = {1, 2, 3};
Cov = {3 2 1,                  
       2 4 0,
       1 0 5};
call randseed(4321);  
X = RandNormal(&N, Mean, Cov);               /* 1000 x 3 matrix     */

/* check the sample mean and sample covariance */
SampleMean = mean(X);                        /* mean of each column */
SampleCov =  cov(X);                         /* sample covariance   */

/* print results */
c = "x1":"x3";
print (X[1:5,])[label="First 5 Obs: MV Normal"];
print SampleMean[colname=c];
print SampleCov[colname=c rowname=c];
/* write SAS/IML matrix to SAS data set for plotting */
create MVN from X[colname=c];  append from X;  close MVN;
quit;

/* create scatter plot matrix of simulated data */
ods graphics on;
proc corr data=MVN COV plots(maxpoints=NONE)=matrix(histogram);
   var x:;
run;

/**********************/
/* Answer to exercise */
/**********************/
/*
proc corr data=Sashelp.iris noprob plots=matrix(histogram);
   by Species;
run;
*/
/**********************/


/***********************************************************************/

/* create a TYPE=COV data set */
data MyCov(type=COV);
input _TYPE_ $ 1-8 _NAME_ $ 9-16 x1 x2 x3;
datalines;
COV     x1      3 2 1
COV     x2      2 4 0
COV     x3      1 0 5
MEAN            1 2 3
run;
proc simnormal data=MyCov outsim=MVN
               nr = 1000                /* size of sample     */
               seed = 12345;            /* random number seed */
   var x1-x3;
run;

/********************************************************************
 Generating Data from Other Multivariate Distributions
 *******************************************************************/

proc iml;
/* specify population mean and covariance */
Mean = {1, 2, 3};
Cov = {3 2 1, 
       2 4 0,
       1 0 5};
call randseed(4321);               
X = RandMVT(100, 4, Mean, Cov);  /* 100 draws; 4 degrees of freedom */

/**********************/
/* Answer to exercise */
/**********************/
create TOut from X[c={X1 X2 X3}];
append from X;
close TOut;

/* The StdDev and range of the t-distributed data are 
   larger than would be expected for normal data */
/*
proc corr data=TOut noprob plots=matrix(histogram);
run;
*/
/**********************/


/********************************************************************
 Mixtures of Multivariate Distributions
 *******************************************************************/

/* create multivariate contaminated normal distrib */
%let N = 100;
proc iml;
mu =   {0 0 0};                            /* vector of means       */
Cov = {10  3  -2,
        3  6   1,
       -2  1   2};
k2 = 100;                                  /* contamination factor  */
p = 0.1;                                   /* prob of contamination */

/* generate contaminated normal (mixture) distribution */
call randseed(1);
call randgen(N1, "Binomial", 1-p, &N); /* N1 unallocated ==> scalar */

X = j(&N, ncol(mu));
X[1:N1,] = RandNormal(N1, mu, Cov);               /* uncontaminated */
X[N1+1:&N,] = RandNormal(&N-N1, mu, k2*Cov);      /* contaminated   */
/* write SAS data set */
create Contam from X[c=('x1':'x3')];  append from X;  close Contam;
quit;

proc corr data=Contam cov plots=matrix(histogram);
   var x1-x3;
run;

/***********************************************************************/

proc iml;
call randseed(12345);
pi = {0.35 0.5 0.15};                  /* mixing probs for k groups */
NumObs = 100;                          /* total num obs to sample   */
N = RandMultinomial(1, NumObs, pi);
print N;
varNames={"x1" "x2" "x3"};
mu =   {32   16   5,                        /* means of Group 1     */
        30    8   4,                        /* means of Group 2     */
        49    7   5};                       /* means of Group 3     */
/* specify lower-triangular within-group covariances */
/*    c11 c21 c31 c22 c32 c33 */
Cov = {17  7   3  5   1   1,                /* cov of Group 1       */
       90 27  16  9   5   4,                /* cov of Group 2       */
      103 16  11  4   2   2};               /* cov of Group 3       */
/* generate mixture distribution: Sample from 
   MVN(mu[i,], Cov[i,]) with probability pi[i] */
p = ncol(pi);                               /* number of variables  */
X = j(NumObs, p);
Group = j(NumObs, 1);
b = 1;                                      /* beginning index      */
do i = 1 to p;
   e = b + N[i] - 1;                        /* ending index         */
   c = sqrvech(Cov[i,]);                    /* cov of group (dense) */
   X[b:e, ] = RandNormal(N[i], mu[i,], c);  /* i_th MVN sample      */
   Group[b:e] = i;
   b = e + 1;                    /* next group starts at this index */
end;
/* save to data set */
Y = Group || X;
create F from Y[c=("Group" || varNames)];  append from Y;  close F;
quit;

proc sgscatter data=F;
   compare y=x2 x=(x1 x3) / group=Group markerattrs=(Size=12);
run;

/********************************************************************
 Conditional Multivariate Normal Distributions
 *******************************************************************/

proc iml;
/* Given a p-dimensional MVN distribution and p-k fixed values for
   the variables x_{k+1},...,x_p, return the conditional mean and
   covariance for first k variables, conditioned on the last p-k 
   variables. The conditional mean is returned as a column vector. */
start CondMVNMeanCov(m, S, _mu, Sigma, _v);
   mu = colvec(_mu);  v = colvec(_v);
   p = nrow(mu);      k = p - nrow(v);

   mu1 = mu[1:k]; 
   mu2 = mu[k+1:p]; 
   Sigma11 = Sigma[1:k, 1:k];
   Sigma12 = Sigma[1:k, k+1:p]; *Sigma21 = T(Sigma12);
   Sigma22 = Sigma[k+1:p, k+1:p];
   m = mu1 + Sigma12*solve(Sigma22, (v - mu2));
   S = Sigma11 - Sigma12*solve(Sigma22, Sigma12`);
finish;
mu = {1 2 3};                                     /* 3D MVN example */
Sigma = {3 2 1, 
         2 4 0,
         1 0 9};
v3 = 2;                                           /* value of x3    */
run CondMVNMeanCov(m, c, mu, Sigma, v3);
print m c;
 /* Given a p-dimensional MVN distribution and p-k fixed values
   for the variables x_{k+1},...,x_p, simulate first k 
   variables conditioned on the last p-k variables. */
start CondMVN(N, mu, Sigma, v);
   run CondMVNMeanCov(m, S, mu, Sigma, v);
   return( RandNormal(N, m`, S) );              /* m` is row vector */
finish;

call randseed(1234);
N = 1000;
z = CondMVN(N, mu, Sigma, v3);   /* simulate 2D conditional distrib */

varNames = "x1":"x2";
create mvn2 from z[c=varNames]; append from z; close mvn2;
quit;

proc sgplot data=mvn2 noautolegend;
   scatter x=x1 y=x2;
   ellipse x=x1 y=x2 / alpha=0.05;
   ellipse x=x1 y=x2 / alpha=0.1;
   ellipse x=x1 y=x2 / alpha=0.2;
   ellipse x=x1 y=x2 / alpha=0.5;
run;

/********************************************************************
 Methods for Generating Data from Multivariate Distributions
 *******************************************************************/

proc iml;
/* Sample from a multivariate Cauchy distribution */
start RandMVCauchy(N, p);
   z = j(N,p,0);  y = j(N,1);         /* allocate matrix and vector */
   call randgen(z, "Normal"); 
   call randgen(y, "Gamma", 0.5);     /* alpha=0.5, unit scale      */
   return( z / sqrt(2*y) );
finish;

/* call the function to generate multivariate Cauchy variates */
N=1000; p = 3;
x = RandMVCauchy(N, p);

/********************************************************************
 The Cholesky Transformation
 *******************************************************************/

proc iml;
Sigma = {9 1, 
         1 1};
U = root(Sigma);
print U[format=BEST5.];                 /* U`*U = Sigma */
/* generate x,y ~ N(0,1), corr(x,y)=0 */
call randseed(12345);
xy = j(2, 1000);
call randgen(xy, "Normal");             /* each col is indep N(0,1) */
 
L = U`; 
zw = L * xy;         /* Cholesky transformation induces correlation */
cov = cov(zw`);      /* check covariance of transformed variables   */
print cov[format=BEST5.];
/* Start with MVN(0, Sigma) data. Apply inverse of L. */
zw = T( RandNormal(1000, {0, 0}, Sigma) );
xy = trisolv(4, L, zw);          /* more efficient than solve(L,zw) */
 
/* Did we succeed in uncorrelating the data? Compute covariance. */
tcov = cov(xy`);
print tcov[format=5.3]; 

/********************************************************************
 The Spectral Decomposition
 *******************************************************************/

data A(type=corr);
_type_='CORR';
input x1-x3;
cards;
1.0  .   .
0.7 1.0  .
0.2 0.4 1.0
;
run;

/* obtain factor pattern matrix from PROC FACTOR */
proc factor data=A N=3 eigenvectors;
   ods select FactorPattern;
run;

/* Perform the same computation in SAS/IML language */
proc iml;
R = {1.0 0.7 0.2,
     0.7 1.0 0.4,
     0.2 0.4 1.0};

/* factor pattern matrix via the eigenvalue decomp.
   R = U*diag(D)*U` = H`*H = F*F` */
call eigen(D, U, R);
F = sqrt(D`) # U;                   /* F is returned by PROC FACTOR */
Verify = F*F`;
print F[format=8.5] Verify;
z = j(1000, 3);            
call randgen(z, "Normal");   /* uncorrelated normal obs: z~MVN(0,I) */

/* Compute x`=F*z` or its transpose x=z*F` */
x = z*F`;                    /* x~MVN(0,R) where R=FF`= corr matrix */
corr = corr(x);              /* sample correlation is close to R    */
print corr[format=5.3];
