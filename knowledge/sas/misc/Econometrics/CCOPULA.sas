

data inparm;
   input Stock1 Stock2 Stock3 Stock4 Stock5 Stock6 Stock7 Stock8 Stock9 Stock10;
datalines;
1       -0.05   0.15    -0.05   0.25    0.05    0.45    -0.05   0.25    0.35
-0.05   1       0.15    -0.05   0.35    0.45    -0.05   0.25    0.15    0.25
0.15    0.15    1       -0.05   0.25    -0.05   0.15    0.45    0.25    0.25
-0.05   -0.05   -0.05   1       0.25    0.15    0.25    0.25    -0.05   0.15
0.25    0.35    0.25    0.25    1       0.15    -0.05   0.25    0.15    0.45
0.05    0.45    -0.05   0.15    0.15    1       -0.05   0.15    0.35    0.15
0.45    -0.05   0.15    0.25    -0.05   -0.05   1       0.05    0.15    0.35
-0.05   0.25    0.45    0.25    0.25    0.15    0.05    1       -0.05   -0.05
0.25    0.15    0.25    -0.05   0.15    0.35    0.15    -0.05   1       0.15
0.35    0.25    0.25    0.15    0.45    0.15    0.35    -0.05   0.15    1

;
run;


proc print data = inparm;
run;

libname mycas cas caslib=casuser;

data mycas.inparm;
set work.inparm;
run;

/* simulate the data from multivariate normal copula */
proc ccopula;
   var Stock1-Stock10;
   define cop normal (corr=mycas.inparm);
   simulate cop /
            ndraws     = 1000000
            seed       = 1234
            outuniform = mycas.normal_unifdata;
run;

/* default time has exponential marginal distribution with parameter 0.5 */
data transofrmedUniform;
   set mycas.normal_unifdata;
   array arr{10} Stock1-Stock10;
   array time{10} time1-time10;
   do i=1 to 10;
      time[i] = 2*quantile("Expo", arr[i]);
   end;
run;

proc print data=transofrmeduniform(obs=10);
   var time1-time10;
run;

/* simulate the data from multivariate gumbel copula */
 
proc ccopula;
   var Stock1-Stock10;
   define copgumbel gumbel (theta=1.2);
   simulate copgumbel /
            ndraws     = 1000000
            seed       = 3243
            outuniform = mycas.gumbel_unifdata;
run; 









