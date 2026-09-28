/***********************************************************************
 Programs for 
 Wicklin, Rick, 2013, Simulating Data with SAS, SAS Institute Inc., Cary NC.

 Chapter 10: Building Correlation and Covariance Matrices
 ***********************************************************************/

ods graphics on;

/********************************************************************
 Converting between Correlation and Covariance Matrices
 *******************************************************************/

proc iml;
/* convert a covariance matrix, S, to a correlation matrix */
start Cov2Corr(S);
   D = sqrt(vecdiag(S));
   return( S / D` / D );        /* divide columns, then divide rows */
finish;

/* R = correlation matrix
   sd = (vector of) standard deviations for each variable 
   Return covariance matrix with sd##2 on the diagonal */
start Corr2Cov(R, sd);
   std = colvec(sd);                  /* convert to a column vector */
   return( std` # R # std );
finish;

S = {1.0  1.0  8.1,                /* covariance matrix             */
     1.0 16.0 18.0,
     8.1 18.0 81.0 };
Corr = Cov2Corr(S);                /* convert to correlation matrix */

sd = sqrt(vecdiag(S));             /* sd = {1 4 9}                  */
Cov = Corr2Cov(Corr, sd);          /* convert to covariance matrix  */
print Corr, Cov;

/********************************************************************
 Testing Whether a Matrix Is a Covariance Matrix
 *******************************************************************/

proc iml;
A = { 2 -1  0,
     -1  2 -1,
      0 -1  2 };

/* finite-precision test of whether a matrix is symmetric */
start SymCheck(A);
   B = (A + A`)/2;
   scale = max(abs(A));
   delta = scale * constant("SQRTMACEPS");
   return( all( abs(B-A)< delta ) );
finish;

/* test a matrix for symmetry */
IsSym = SymCheck(A);
print IsSym;

/***********************************************************************/

G = root(A);
G = root(A, "NoError");                   /* SAS/IML 12.1 and later */
if G=. then print "The matrix is not positive semidefinite";
eigval = eigval(A);
print eigval;
if any(eigval<0) then print "The matrix is not positive semidefinite";

/********************************************************************
 Techniques to Build a Covariance Matrix
 *******************************************************************/

/* Method 1: Base SAS approach */
proc corr data=Sashelp.Class COV NOMISS outp=Pearson;
   var Age Height Weight;
   ods select Cov;
run;

/* Method 2: equivalent SAS/IML computation */
proc iml;
use Sashelp.Class;
read all var {"Age" "Height" "Weight"} into X;
close Sashelp.Class;

Cov = cov(X);

/***********************************************************************/

proc iml;
N = 4;                            /* want 4x4 symmetric matrix      */
call randseed(1);
v = j(N*(N+1)/2, 1);              /* allocate lower triangular      */
call randgen(v, "Uniform");       /* fill with random               */
x = sqrvech(v);                   /* create symmetric matrix from v */
print x[format=5.3];

/***********************************************************************/

/* Add a multiple of diag(A) so that A is diagonally dominant. */
start Ridge(A, scale);         /* Input scale >= 1                  */
   d = vecdiag(A);
   s = abs(A)[,+] - d;         /* sum(abs of off-diagonal elements) */
   lambda = scale * (max(s/d) - 1); 
   return( A + lambda*diag(d) );
finish;

/* assume x is symmetric matrix */
H = Ridge(x, 1.01);            /* scale > 1 ==> H is pos definite   */
print H;

/**********************/
/* Answer to exercise */
/**********************/
proc iml;
/* Add a multiple of diag(A) so that A is diagonally dominant. */
start Ridge(A, scale);         /* Input scale >= 1                  */
   d = vecdiag(A);
   s = abs(A)[,+] - d;         /* sum(abs of off-diagonal elements) */
   lambda = scale * (max(s/d) - 1); 
   return( A + lambda*diag(d) );
finish;

/* Return NumSamples x (N*N) matrix. Each row contains an N x N 
   symmetric PD matrix. The scale parameter is used for the ridging.*/
start RandSymUsingRidge(NumSamples, N, scale);
   Y = j(NumSamples, N##2);            /* allocate return values    */
   v = j(NumSamples, N*(N+1)/2);       /* allocate lower triangular */
   call randgen(v, "Uniform");         /* fill with random          */
   do i = 1 to NumSamples;
      A = sqrvech(v[i,]);
      B = Ridge(A, scale);
      Y[i,] = shape(B, 1);             /* pack matrix in row of Y   */
   end;
   return( Y );
finish;

N = 4;                             /* get 4x4 symmetric PD matrices */
call randseed(1);
Y = RandSymUsingRidge(5, N, 1.1);          /* get five 4x4 matrices */
/* print first matrix */
Y1 = shape(Y[1,], N);
print Y1;
quit;
/**********************/


/***********************************************************************/

proc iml;
/* variance components: diag({var1, var2,..,varN}), var_i>0 */
start VarComp(v);
   return( diag(v) );
finish;

vc = VarComp({16,9,4,1});
print vc;

/* compound symmetry, v>0:
   {v+v1    v1    v1    v1,
      v1  v+v1    v1    v1,
      v1    v1  v+v1    v1,
      v1    v1    v1  v+v1  };
*/   
start CompSym(N, v, v1);
   return( j(N,N,v1) + diag( j(N,1,v) ) );
finish;

cs = CompSym(4, 4, 1);
print cs;

/* Toeplitz:
   {s##2 s1   s2   s3,
    s1   s##2 s1   s2,
    s2   s1   s##2 s1,
    s3   s2   s1   s##2 };
   Let u = {s1 s2 s3};
*/   
toep = toeplitz( {4 1 2 3} );
print toep;

/* AR1 is special case of Toeplitz */
/* autoregressive(1):
   s##2 * {1      rho    rho##2 rho##3,
           rho    1      rho    rho##2,
           rho##2 rho    1      rho   ,
           rho##3 rho##2 rho    1     }; 
   Let u = {rho rho##2 rho##3} 
*/
start AR1(N, s, rho);
   u = cuprod(j(1,N-1,rho));                  /* cumulative product */
   return( s##2 # toeplitz(1 || u) );
finish;

ar1 = AR1(4, 1, 0.25);
print ar1;

/********************************************************************
 Generating Matrices from the Wishart Distribution
 *******************************************************************/

proc iml;
call randseed(12345);
NumSamples = 1000;                /* number of Wishart draws        */
N = 50;                           /* MVN sample size                */
Sigma = {9 1, 
         1 1};
/* Simulate matrices. Each row is scatter matrix */
A = RandWishart(NumSamples, N-1, Sigma); 
B = A / (N-1);                    /* each row is covariance matrix  */

S1 = shape(B[1,], 2, 2);          /* first row, reshape into 2 x 2  */
S2 = shape(B[2,], 2, 2);          /* second row, reshape into 2 x 2 */
print S1 S2;                      /* two 2 x 2 covariance matrices  */

SampleMean = shape(B[:,], 2, 2);  /* mean covariance matrix         */
print SampleMean;
/* for exercise */
create CovB from B[c={"B11" "B12" "B21" "B22" }];
append from B;
close CovB;

/**********************/
/* Answer to exercise */
/**********************/
proc univariate data=CovB;
   var B11 B12 B22;
   histogram B11 B12 B22;
   ods select Histogram;
run;

proc means data=CovB mean stddev P5 P95;
   var B11 B12 B22;
run;
/**********************/

/* Functions to generate a random correlation matrix */
 
proc iml;
/* Generate random orthogonal matrix G. W. Stewart (1980).    
   Algorithm from QMULT MATLAB routine by Higham (1991) */
start RandOrthog(n);
   A = I(n);                            /* identity matrix          */
   d = j(n,1,0);
   d[n] = sgn(RndNormal(1,1));          /* +/- 1                    */
   do k = n-1 to 1 by -1; 
      /* generate random Householder transformation */
      x = RndNormal(n-k+1,1);           /* column vector from N(0,1) */
      s = sqrt(x[##]);                  /* norm(x)                  */
      sgn = sgn( x[1] );
      s = sgn*s;
      d[k] = -sgn;
      x[1] = x[1] + s;
      beta = s*x[1];
      /* apply the Householder transformation to A */
      y = x`*A[k:n, ];
      A[k:n, ] = A[k:n, ] - x*(y/beta);
   end;
   A = d # A;              /* change signs of i_th row when d[i]=-1 */
   return(A);
finish;

/* helper functions */
/* return matrix of same size as A with 
   m[i,j]= {  1 if A[i,j]>=0
           { -1 if A[i,j]< 0
   Similar to the SIGN function, except SIGN(0)=0 */
start sgn(A);
   return( choose(A>=0, 1, -1) );
finish;

/* return (r x c) matrix of standard normal variates */
start RndNormal(r,c);
   x = j(r,c);
   call randgen(x, "Normal");
   return(x);
finish;

start RandMatWithEigenval(lambda);
   n = ncol(lambda);                 /* assume lambda is row vector */
   Q = RandOrthog(n);
   return( Q`*diag(lambda)*Q );
finish;

/* apply Givens rotation to A in (i,j) position. Naive implementation is
   G = I(nrow(A));  G[i,i]=c;  G[i,j]=s; G[j,i]=-s;  G[j,j]=c;   
   A = G`*A*G; */
start ApplyGivens(A,i,j);
   Aii = A[i,i];   Aij = A[i,j];   Ajj = A[j,j];
   t = (Aij + sqrt(Aij##2 - (Aii-1)*(Ajj-1))) / (Ajj - 1);
   c = 1/sqrt(1+t##2);
   s = c*t;
   Ai = A[i,]; Aj = A[j,];    /* linear combo of i_th and j_th ROWS */
   A[i,] = c*Ai - s*Aj;    A[j,] = s*Ai + c*Aj;
   Ai = A[,i]; Aj = A[,j];    /* linear combo of i_th and j_th COLS */
   A[,i] = c*Ai - s*Aj;    A[,j] = s*Ai + c*Aj;
finish;

/* Generate random correlation matrix (Davies and Higham (2000))
   Input: lambda = desired eigenvalues (scaled so sum(lambda)=n)
   Output: random N x N matrix with eigenvalues given by lambda  */
start RandCorr(_lambda);
   lambda = rowvec(_lambda);                   /* ensure row vector   */
   n = ncol(lambda);
   lambda = n * lambda /sum(lambda);          /* ensure sum(lambda)=n */
   maceps = constant("MACEPS");

   corr = RandMatWithEigenval(lambda);
   convergence = 0;
   do iter = 1 to n while (^convergence);
      d = vecdiag(corr);
      if all( abs(d-1) < 1e3*maceps ) then     /* diag=1 ==> done     */
         convergence=1;
      else do;                        /* apply Givens rotation        */
         idxgt1 = loc(d>1);
         idxlt1 = loc(d<1);   
         i = idxlt1[1];               /* first index for which d[i]<1 */
         j = idxgt1[ncol(idxgt1)];    /* last index for which d[j]>1  */
         if i > j then do;            /* -or- */
            i = idxgt1[1];            /* first index for which d[i]>1 */
            j = idxlt1[ncol(idxlt1)]; /* last index for which d[j]<1  */
         end;
         run ApplyGivens(Corr,i,j);
         corr[i,i] = 1;               /* avoid rounding error: diag=1 */
      end;
   end;
   return(corr);
finish;

store module=_all_;
quit;
/* Helper functions have been defined and saved. */


/********************************************************************
 Generating Random Correlation Matrices
 *******************************************************************/

/* Define and store the functions for random correlation matrices */
*%include "C:\<path>\SimulatingData.sas"; 
%include "RandCorr.sas"; 

proc iml;
load module=_all_;                     /* load the modules */
/* test it: generate 4 x 4 matrix with given spectrum */
call randseed(4321);
lambda = {2 1 0.75 0.25};           /* notice that sum(lambda) = 4  */
R = RandCorr(lambda);               /* R has lambda for eigenvalues */
eigvalR = eigval(R);                /* verify eigenvalues           */
print R, eigvalR;

/* for the exercise: generate 1,000 3x3 matrices with given spectrum */
lambda = {1.5 1 0.5};               /* notice that sum(lambda) = 3  */
result = j(1000,3);
do i = 1 to nrow(result);
   R = RandCorr(lambda`);
   result[i, ] = T( R[{2 3 6}] );
end;
create RandCorrSpectrum from result[c={R12 R13 R23}];
append from result;
close RandCorrSpectrum;

/**********************/
/* Answer to exercise */
/**********************/
proc univariate data=RandCorrSpectrum;
   histogram R12 R13 R23;
   ods select Histogram;
run;
/**********************/


/********************************************************************
 When Is a Correlation Matrix Not a Correlation Matrix?
 *******************************************************************/

proc iml;
C = {1.0 0.3 0.9,
     0.3 1.0 0.9,
     0.9 0.9 1.0};
eigval = eigval(C);
print eigval;

/********************************************************************
 The Nearest Correlation Matrix
 *******************************************************************/

proc iml;
/* Project symmetric X onto S={positive semidefinite matrices}.
   Replace any negative eigenvalues of X with zero */
start ProjS(X);
   call eigen(D, Q, X);               /* notice that X = Q*D*Q`     */
   V = choose(D>0, D, 0);
   W = Q#sqrt(V`);                    /* form Q*diag(V)*Q`          */
   return( W*W` );                    /* W*W` = Q*diag(V)*Q`        */
finish;

/* project square X onto U={matrices with unit diagonal}.
   Return X with the diagonal elements replaced by ones. */
start ProjU(X);
   n = nrow(X);
   Y = X;
   Y[do(1, n*n, n+1)] = 1;            /* set diagonal elements to 1 */
   return ( Y );
finish;

/* the matrix infinity norm is the max abs value of the row sums */
start MatInfNorm(A);
   return( max(abs(A[,+])) );
finish;

/* Given a symmetric matrix, A, project A onto the space of PSD 
   matrices. The function uses the algorithm of Higham (2002) to 
   return the matrix X that is closest to A in the Frobenius norm.  */
start NearestCorr(A);
   maxIter = 100; tol  = 1e-8;        /* initialize parameters      */
   iter = 1;      maxd = 1;           /* initial values             */ 
   Yold = A;  Xold = A;  dS = 0;

   do while( (iter <= maxIter) & (maxd > tol) );
     R = Yold - dS;                   /* dS is Dykstra's correction */
     X = ProjS(R);                    /* project onto S={PSD}       */
     dS = X - R;
     Y = ProjU(X);                    /* project onto U={Unit diag} */

     /* How much has X changed? (Eqn 4.1) */
     dx = MatInfNorm(X-Xold) / MatInfNorm(X);
     dy = MatInfNorm(Y-Yold) / MatInfNorm(Y);
     dxy = MatInfNorm(Y - X) / MatInfNorm(Y);
     maxd = max(dx,dy,dxy);
     iter = iter + 1; 
     Xold = X;  Yold = Y;             /* update matrices            */
   end;
   return( X );                       /* X is positive semidefinite */
finish;

/* finance example */
C = {1.0 0.3 0.9,
     0.3 1.0 0.9,
     0.9 0.9 1.0};
R = NearestCorr(C);
print R[format=7.4];

/**********************/
/* Answer to exercise */
/**********************/
/*
call randseed(1);
size = T( do(50, 300, 50) );
time = j(nrow(size), 1);
do i = 1 to nrow(size);
   t0 = time();
   N = size[i];
   v = j(N*(N+1)/2, 1);
   call randgen(v, "Uniform");
   A = sqrvech(v);

   x = NearestCorr(A);
   time[i] = time() - t0;
end;
create Timing var {"Size" "Time"}; append; close Timing;
quit;

proc sgplot data=Timing;
   series x=Size y=Time;
   xaxis grid; yaxis grid;
run;
*/
/**********************/

