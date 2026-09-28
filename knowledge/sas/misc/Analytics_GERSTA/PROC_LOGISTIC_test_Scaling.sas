/* Set this option to get more details on ressource usage */
options fullstimer;


/* Set run ID and log file to keep track of results */
%let runid=v01;

* proc printto log="C:\DATEN\KSPEC\test&runid..log";
libname test "C:\DATEN\KSPEC";


/* Specify number of records and number of variables (>100)*/
%let rec=10000;
%let vars=200;


/* Generate simulated data set with random numbers uniform distribution */
data test.tmp1;
array predictors (&vars)v001 - v&vars;
do i=1 to &rec;
   do j=1 to &vars;
   predictors(j)=ranuni(123);
   end;
   output;
end;
drop i j;
run;

/* Add dependent variable as function of input to data set */
data test.tmp1;
 set test.tmp1;
 array predictors (&vars) v001 - v&vars;
 y=0.4+ 0.2*v001+0.05*v002-0.07*v003+(rannor(234)/100);
 if y<0 then y=0;
 do i=1 to &vars;
   predictors(i)=round(predictors(i),1);
  end;
  y=round(y,1);
  drop i;
run;

/* Use GLMSELECT for 1st pass effect selection */
ods graphics;
proc glmselect data=test.tmp1 noprint plots=criteria;
class v001--v&vars;
model y = v001--v&vars / selection=forward(stop=aicc);
run;
ods graphics off;



Title "Selected effects: &_GLSIND1 ";
/* Use LOGISTIC to model for remaining effects */

ods graphics on;
proc logistic data=test.tmp1 outest=betas covout multipass noprint   /*plots=(ALL)*/;
   model y(event='1')= &_GLSIND1
                / selection=forward
                  slentry=0.05
                  slstay=0.05
				  nodummyprint nodesignprint
                  ;
   output out=pred1 p=phat lower=lcl upper=ucl         ;
run;
ods graphics off;


/* Use LOGISTIC to model for all effects and then eliminate using forward selection */
proc logistic data=test.tmp1 outest=betas covout;
   model y(event='1')= v001 -- v&vars
                / selection=forward
                  slentry=0.05
                  slstay=0.05
                  ;
   output out=pred2 p=phat lower=lcl upper=ucl         ;
run;
