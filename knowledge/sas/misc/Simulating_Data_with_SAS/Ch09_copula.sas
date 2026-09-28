/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 9: Advanced Simulation of Multivariate Data
 ***********************************************************************/

ods graphics on;

/********************************************************************
 Generating Multivariate Binary Variates
 *******************************************************************/

/* Algorithm from 
   Emrich, L.J.  and Piedmonte, M. R., 1991,
   "A Method for Generating High-Dimensional Multivariate Binary Variables",
   The American Statistician, 45, p. 302--304
*/

proc iml;
/* Let X1, X2,...,Xd be binary variables, let 
   p = (p1,p2,...,pd) the their expected values and let
   Delta be the d x d matrix of correlations.
   This function returns 1 if p and Delta are feasible for binary 
   variables. The function also computes lower and upper bounds on the
   correlations, and returns them in LBound and UBound, respectively */
start CheckMVBinaryParams(LBound, UBound, _p, Delta);
   p = rowvec(_p);    q = 1 - p;         /* make p a row vector     */
   d = ncol(p);                          /* number of variables     */

   /* 1. check range of Delta; make sure p and Delta are feasible   */
   PP = p`*p;        PQ = p`*q;
   QP = q`*p;        QQ = q`*q;
   A = -sqrt(PP/QQ); B = -sqrt(QQ/PP);   /* matrices                */
   LBound = choose(A>B,A,B);             /* elementwise max(A or B) */
   LBound[loc(I(d))] = 1;                /* set diagonal to 1       */
   A =  sqrt(PQ/QP); B =  sqrt(QP/PQ);
   UBound = choose(A<B,A,B);             /* min(A or B)             */
   UBound[loc(I(d))] = 1;                /* set diagonal to 1       */

   /* return 1 <==> specified  means and correlations are feasible  */
   return( all(Delta >= LBound) & all(Delta <= UBound) );
finish;

/***********************************************************************/

/* Objective: Find correlation, rho, that is zero of this function.
   Global variables:
   pj = prob of success for binary var Xj
   pk = prob of success for binary var Xk
   djk = target correlation between Xj and Xk    */
start MVBFunc(rho)   global(pj, pk, djk);
   Phi = probbnrm(quantile("Normal",pj), quantile("Normal",pk), rho);
   qj = 1-pj; qk = 1-pk;
   return( Phi - pj*pk - djk*sqrt(pj*qj*pk*qk) );
finish;

/***********************************************************************/

start RandMVBinary(N, p, Delta) global(pj, pk, djk);
   /* 1. Check parameters. Compute lower/upper bounds for all (j,k) */
   if ^CheckMVBinaryParams(LBound, UBound, p, Delta) then do;
      print "The specified correlation is invalid." LBound Delta UBound;
      STOP;
   end;

   q = 1 - p;  
   d = ncol(Delta);                          /* number of variables  */

   /* 2. Construct intermediate correlation matrix by solving the 
         bivariate CDF (PROBBNRM) equation for each pair of vars */
   R = I(d);
   do j = 1 to d-1;
      do k = j+1 to d;
         pj=p[j]; pk=p[k]; djk = Delta[j,k];      /* set global vars */
         /* TYPO in first edition: search for root on [-1,1] */
         *R[j,k] = bisection(-1, 1);              /* pre-12.1 */
         R[j,k] = froot("MVBFunc", {-1 1});       /* 12.1 */
         R[k,j] = R[j,k];
      end;
   end;

   /* 3: Generate MV normal with mean 0 and covariance R */
   X = RandNormal(N, j(1,d,0), R);
   /* 4: Obtain binary variable from normal quantile */
   do j = 1 to d;
      X[,j] = (X[,j] <= quantile("Normal", p[j])); /* convert to 0/1 */
   end;
   return (X);
finish;

call randseed(1234);
p = {0.25 0.75 0.5};               /* expected values of the X[j]   */
Delta = { 1    -0.1  -0.25,
         -0.1   1     0.25,
         -0.25  0.25  1    };      /* correlations between the X[j] */
X = RandMVBinary(1000, p, Delta);

/* compare sample estimates to parameters */
mean = mean(X);
corr = corr(X);
print p, mean, Delta, corr[format=best6.];

/***********************************************************************/

/* Plot for mean mapping method of generating correlated ordinal data */
proc iml;
call streaminit(1);
X = RandNormal(1e4, {0 0}, {1 0.5137, 0.5137 1});
create BivarNormal from X[c={"x" "y"}];
append from X;
close BivarNormal;

Y = {0 -0.842,
     0 -0.385,
     0 0.253,
 0.524 -0.842, 
 0.524 -0.385,
 0.524 0.253}; 
create inter from Y[c={p1 p2}];append from Y;close inter;

Y = {-1.2 -1.5,
     -1.2 -0.75,
     -1.2 -0.2,
     -1.2  0.8,
   0.05 -1.5,
   0.05 -0.75,
   0.05 -0.2,
   0.05  0.8,
      1 -1.5,
      1 -0.75,
      1 -0.2,
      1  0.8}; 
b1 = Y[,1]; b2 = Y[,2];
labl = {"(1,1)", "(1,2)", "(1,3)", "(1,4)", 
        "(2,1)", "(2,2)", "(2,3)", "(2,4)", 
        "(3,1)", "(3,2)", "(3,3)", "(3,4)" };

create label var {b1 b2 labl};append;close label;
quit;

data Bivar;
merge BivarNormal inter label;
run;

ods graphics / antialiasmax=10000;
proc sgplot data=Bivar noautolegend nocycleattrs;
   ellipse x=x y=y / alpha=0.25  transparency=0.5; 
   ellipse x=x y=y / alpha=0.50  transparency=0.5; 
   ellipse x=x y=y / alpha=0.75  transparency=0.5; 
   refline 0 0.524 / axis=x lineattrs=(thickness=2);
   refline -0.842 -0.385 0.253 / axis=y lineattrs=(thickness=2);
   scatter x=p1 y=p2 / markerattrs=(size=10 symbol=CircleFilled);
   scatter x=b1 y=b2 / markerattrs=(size=0) datalabel=labl
                    datalabelattrs=(size=14);
   xaxis display=(nolabel) min=-2 max=2.1 offsetmax=0;
   yaxis display=(nolabel) min=-2 max=2.1 offsetmax=0;
run;
/***********************************************************************/

/*******************************************************************
   SAS/IML functions for the implementation of 
   Kaiser, S. and Tr\"ager, D. and Leisch, F., (2011)
   "Generating Correlated Ordinal Random Values,"
   Technical ReportL University of Munich, Department of Statistics
   http://epub.ub.uni-muenchen.de/12157/
********************************************************************/
proc iml;
/* OrdN: number of values for each variable */
start OrdN(P);
   return( countn(P, "col") );
finish;

/* OrdMean: E(A) = sum(i*p[i]) = expected value for each variable   */
start OrdMean(P);
   x = T(1:nrow(P));                 /* values of ordinal vars      */
   return( (x#P)[+,] );              /* expected values E(X)        */
finish;

/* OrdVar: variance for each variable */
start OrdVar(P);
   d = ncol(P);   m = OrdMean(P);
   x = T(1:nrow(P));                 /* values                      */
   var = j(1, d, 0);
   do i = 1 to d;
      var[i] = sum( (x - m[i])##2 # P[,i] );    /* defn of variance */
   end;
   return( var );
finish;

/* OrdCDF: Given PMF, compute CDF = cusum(PDF) */
start OrdCDF(P);
   d = ncol(P);
   cdf = j(nrow(P), ncol(P));        /* cumulative probabilities    */
   do i = 1 to d;
      cdf[,i] = cusum(P[,i]);
   end;
   return( choose(P=., ., cdf) );    /* missing vals for short cols */
finish;

/* Function that returns ordered pairs on a uniform grid of points.
   Return value is an (Nx*Ny x 2) matrix */
start Expand2DGrid( _x, _y );
   x  = colvec(_x); y  = colvec(_y);
   Nx = nrow(x);    Ny = nrow(y);
   x = repeat(x, Ny);
   y = shape( repeat(y, 1, Nx), 0, 1 );
   return ( x || y );
finish;

/* OrdQuant: Compute normal quantiles for CDF(P) */
start OrdQuant(P);
   N = OrdN(P);
   CDF = OrdCDF(P);
   /* QUANTILE function does not accept 1 as parameter */
   /* Replace 1 with missing value to prevent error */
   idx = loc(CDF > 1 - 2e-6 );
   CDF[idx] = .;
   quant = quantile( "Normal", cdf );
   do j = 1 to ncol(P);      /* set upper quantile to .I = infinity */
      quant[N[j],j] = .I;    /* .I has special meaning to BIN func  */
   end;                      
   return( quant );
finish;

/* OrdFindRoot: Use bisection to find the MV normal correlation that 
   produces a specified MV ordinal correlation. */
start OrdFindRoot(P1, P2,  target);
   N1 = countn(P1);   N2 = countn(P2);
   q1 = OrdQuant(P1); q2 = OrdQuant(P2);
   v1 = q1[1:N1-1];   v2 = q2[1:N2-1];
   g = Expand2DGrid(v1, v2);
   /* find rho such that sum(probbnrm(g[,1], g[,2], rho))=target    */
   /* Bisection: find root on bracketing interval [a,b] */
   a = -1; b = 1;                 /* look for correlation in [-1,1] */
   dx = 1e-8; dy = 1e-5;
   do i = 1 to 100;               /* iterate until convergence      */
      c = (a+b)/2;
      Fc = sum( probbnrm(g[,1], g[,2], c) ) - target;
      if (abs(Fc) < dy) | (b-a)/2 < dx then 
         return(c);
      Fa = sum( probbnrm(g[,1], g[,2], a) ) - target;
      if Fa#Fc > 0 then a = c;
      else b = c;
   end;
   return (.);                    /* no convergence                 */
finish;

/* OrdMVCorr: Compute a MVN correlation matrix from the PMF and 
   the target correlation matrix for the ordinal variables. */
start OrdMVCorr(P, Corr);
   d = ncol(P);
   N = OrdN(P);
   mean = OrdMean(P);
   var  = OrdVar(P);
   cdf  = OrdCDF(P);
   R = I(d);
   do i = 1 to d-1;
      sumCDFi = sum(cdf[1:N[i]-1, i]); 
      do j = i+1 to d;
         sumCDFj = sum(cdf[1:N[j]-1, j]); 
         hStar = Corr[i,j] * sqrt(var[i]*var[j]) + mean[i]*mean[j] 
                 - N[i]*N[j] + N[i]*sumCDFj + N[j]*sumCDFi;

         R[i,j] = OrdFindRoot(P[,i], P[,j], hStar);
         R[j,i] = R[i,j];
      end;
   end;
   return(R);
finish;

/* test the function */
/*
Corr = {1.0  0.4  0.3,
        0.4  1.0  0.4,
        0.3  0.4  1.0 };
R = OrdMVCorr(P, Corr);
print R;
*/

/* RandMVOrdinal: 
   N     Number of desired observations from MV ordinal distribution, 
   P     Matrix of PMF for ordinal vars. The j_th col is the j_th PMF.
         Use missing vals if some vars have fewer values than others.
   Corr  Desired correlation matrix for ordinal variables. Not every
         matrix is a valid as the correlation of ordinal variables. */
start RandMVOrdinal(N, P, Corr);
   d = ncol(P);
   C = OrdMVCorr(P, Corr);     /* 1. compute correlation matrix, C  */
   mu = j(1, d, 0);
   X = RandNormal(N, mu, C);   /* 2. simulate X ~ MVN(0,C)          */
   N = OrdN(P);
   quant = OrdQuant(P);        /* compute normal quantiles for PMFs */
   do j = 1 to d;              /* 3. convert to ordinal             */
      X[,j] = bin(X[,j], .M // quant[1:N[j],j]);
   end;
   return(X);
finish;

store module=_all_;
quit;
/* Helper functions have been defined and saved. */


/********************************************************************
 Generating Multivariate Ordinal Variates
 *******************************************************************/


/**********************/
/* Answer to exercise */
/**********************/
data Table(keep=x);
call streaminit(4321);
array p[4] _temporary_ (0.2 0.15 0.25 0.4);
do i = 1 to 10000;
   x = rand("Table", of p[*]);           /* sample with replacement */
   output;
end;
run;

proc means data=Table Mean Var;
run;
/**********************/


/***********************************************************************/

/* Define and store the functions for random ordinal variables */
%include "RandMVOrd.sas"; 

proc iml;
load module=_all_;                     /* load the modules */
    /* P1   P2    P3  */
P = {0.25  0.50  0.20 ,
     0.75  0.20  0.15 ,
      .    0.30  0.25 ,
      .     .    0.40 };

/* expected values and variance for each ordinal variable */
Expected = OrdMean(P) // OrdVar(P);
varNames = "X1":"X3";
print Expected[r={"Mean" "Var"} c=varNames];
/* test the RandMVOrd function */
Delta = {1.0  0.4  0.3,
         0.4  1.0  0.4,
         0.3  0.4  1.0 };

call randseed(54321);
X = RandMVOrdinal(1000, P, Delta);
first = X[1:5,];
print first[label="First 5 Obs: Multivariate Ordinal"];

/***** for exercise *****/
create MVOrdSim from X[c={x1 x2 x3}]; append from X; close;
mv = mean(X) // var(X);   
corr = corr(X);
varNames = "X1":"X3";
print mv[r={"Mean" "Var"} c=varNames], corr;

/**********************/
/* Answer to exercise */
/**********************/
proc freq data=MVOrdSim;
run;
/**********************/


/********************************************************************
 Reordering Multivariate Data: The Iman-Conover Method
 *******************************************************************/

/* Use Iman-Conover method to generate MV data with known marginals
   and known rank correlation. */
proc iml;
start ImanConoverTransform(Y, C);
   X = Y; 
   N = nrow(X);
   R = J(N, ncol(X));
   /* compute scores of each column */
   do i = 1 to ncol(X);
      h = quantile("Normal", rank(X[,i])/(N+1) );
      R[,i] = h;
   end;
   /* these matrices are transposes of those in Iman & Conover */
   Q = root(corr(R)); 
   P = root(C); 
   S = solve(Q,P);                      /* same as  S = inv(Q) * P; */
   M = R*S;             /* M has rank correlation close to target C */

   /* reorder columns of X to have same ranks as M.
      In Iman-Conover (1982), the matrix is called R_B. */
   do i = 1 to ncol(M);
      rank = rank(M[,i]);
      tmp = X[,i];       /* TYPO in first edition */
      call sort(tmp);
      X[,i] = tmp[rank];
   end;
   return( X );
finish;

/* Step 1: Specify marginal distributions */
call randseed(1);
N = 100;
A = j(N,4);   y = j(N,1);
distrib = {"Normal" "Lognormal" "Expo" "Uniform"};
do i = 1 to ncol(distrib);
   call randgen(y, distrib[i]);
   A[,i] = y;
end;

/* Step 2: specify target rank correlation */
C = { 1.00  0.75 -0.70  0,
      0.75  1.00 -0.95  0,
     -0.70 -0.95  1.00 -0.2,
      0     0    -0.2   1.0};

X = ImanConoverTransform(A, C);
RankCorr = corr(X, "Spearman");
print RankCorr[format=5.2];

/* write to SAS data set */
create MVData from X[c=("x1":"x4")];  append from X;  close MVData;
quit;

proc corr data=MVData Pearson Spearman noprob plots=matrix(hist);
   var x1-x4;
run;

/**********************/
/* Answer to exercise */
/**********************/
proc univariate data=MVData;
   var x2 x3;
   histogram x2 / lognormal endpoints=(0 to 22 by 2);
   histogram x3 / exponential endpoints=(0 to 7);
   ods select histogram;
run;
/**********************/


/********************************************************************
 Generating Data from Copulas
 *******************************************************************/

proc iml;
call randseed(12345);
Sigma = {1.0  0.6,
         0.6  1.0};
Z = RandNormal(1e4, {0,0}, Sigma);
U = cdf("Normal", Z);           /* columns of U are U(0,1) variates */
gamma = quantile("Gamma", U[,1], 4);      /* gamma ~ Gamma(alpha=4) */
expo = quantile("Expo", U[,2]);           /* expo ~ Exp(1)          */
X = gamma || expo;
/* if Z~MVN(0,Sigma), corr(X) is often close to Sigma,
   where X=(X1,X2,...,Xm) and X_i = F_i^{-1}(Phi(Z_i)) */
rhoZ = corr(Z)[1,2];                    /* extract corr coefficient */
rhoX = corr(X)[1,2];
print rhoZ rhoX;

/* even though corr(X) ^= Sigma, you can often choose a target
   correlation, such as 0.6, and then choose Sigma so that corr(X)
   has the target correlation. */
Z0=Z; U0=U; X0=X;                             /* save original data */ 
Sigma = I(2);
rho = T( do(0.62, 0.68, 0.01) );
rhoTarget = j(nrow(rho), 1);
do i = 1 to nrow(rho);
   Sigma[1,2]=rho[i]; Sigma[2,1]=Sigma[1,2];
   Z = RandNormal(1e4, {0,0}, Sigma);           /* Z ~ MVN(0,Sigma) */
   U = cdf("Normal", Z);                        /* U_i ~ U(0,1)     */
   gamma = quantile("Gamma", U[,1], 4);         /* X_1 ~ Gamma(4)   */
   expo = quantile("Expo", U[,2]);              /* X_2 ~ Expo(1)    */
   X = gamma||expo;
   rhoTarget[i] = corr(X)[1,2];                 /* corr(X) = ?      */
end;
print rho rhoTarget[format=6.4];

RankCorrZ = corr(Z0, "Spearman")[1,2];
RankCorrU = corr(U0, "Spearman")[1,2];
RankCorrX = corr(X0, "Spearman")[1,2];
print RankCorrZ RankCorrU RankCorrX;

Q = Z||U||X;
labels = {Z1 Z2 U1 U2 X1 X2};
create CorrData from Q[c=labels];
append from Q;
close CorrData;


proc sgplot data=CorrData(obs=1000);
   scatter x=U1 y=U2;
run;

/**********************/
/* Answer to exercise */
/**********************/
proc corr data=CorrData fisher(rho0=0.6);
   var Z1 Z2;     
   ods select FisherPearsonCorr;
run;
/* similar for X1 X2  */
/**********************/


/***********************************************************************/

/* Step 2: fit normal copula
   Step 3: simulate data, transformed to uniformity */
proc copula data=MVData;
   var x1-x4;
   fit normal;
   simulate / seed=1234  ndraws=100
              marginals=empirical  outuniform=UnifData;
run;
/* Step 4: use inverse CDF to invert uniform marginals */
data Sim;
set UnifData;
normal = quantile("Normal", x1);
lognormal = quantile("LogNormal", x2);
expo = quantile("Exponential", x3);
uniform = x4;
run;
/* Compare original distribution of data to simulated data */
proc corr data=MVData Spearman noprob plots=matrix(hist);
   title "Original Data";
   var x1-x4;
run;

proc corr data=Sim Spearman noprob plots=matrix(hist);
   title "Simulated Data";
   var normal lognormal expo uniform;
run;

/**********************/
/* Answer to exercise */
/**********************/
proc corr data=Sim Spearman FISHER noprob;
   var normal lognormal expo uniform;
   ods select FisherSpearmanCorr;
run;
/**********************/

