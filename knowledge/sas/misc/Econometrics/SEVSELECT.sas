/*--------------------------------------------------------------------------

                    SAS Sample Library

        Name: svslex07.sas
 Description: Example program from SAS Econometrics
              Procedures User's Guide, The SEVSELECT Procedure
       Title: Scale Regression Model Selection
     Product: SAS Econometrics Software
        Keys: Severity Distribution Modeling
        PROC: SEVSELECT
       Notes:

----------------------------------------------------------------------------*/


proc format casfmtlib='myfmtlib';
   value genderFmt 1='Female'
                   2='Male';
run;

data losses(keep=gender carType education carSafety income
                 lossAmount deductible limit);
   call streaminit(12345);
   array sx{8} _temporary_;
   array sbeta{9} _TEMPORARY_ (5 0.6 0.4 -0.75 -0.3 0.4 0.7 -0.5 -0.3);

   length carType $8 education $16;
*   format gender genderFmt.;

   sigma = 0.5;
   do lossEventId=1 to 5000;
      /* Simulate policyholder and vehicle attributes */
      do i=1 to dim(sx);
         sx(i) = 0;
      end;

      if (rand('UNIFORM') < 0.5) then do;
         gender = 1; * female;
         sx(2) = 1;
      end;
      else do;
         gender = 2; * male;
      end;

      if (rand('UNIFORM') < 0.7) then do;
         carInt = 1;
         carType = 'Sedan';
      end;
      else do;
         carInt = 2;
         carType = 'SUV';
         sx(1) = 1;
      end;

      educationLevel = rand('UNIFORM');
      if (educationLevel < 0.5) then do;
         eduInt = 1;
         education = 'High School';
      end;
      else if (educationLevel < 0.85) then do;
         eduInt = 2;
         education = 'College';
         if (carInt=1) then
            sx(8) = 1;
         else
            sx(6) = 1;
      end;
      else do;
         eduInt = 3;
         education = 'AdvancedDegree';
         if (carInt=1) then
            sx(7) = 1;
         else
            sx(5) = 1;
      end;

      carSafety = rand('UNIFORM'); /* scaled to be between 0 & 1 */
      sx(3) = carSafety;

      income = MAX(15000,int(rand('NORMAL', eduInt*30000, 50000)))/100000;
      sx(4) = income;

      /* Simulate lognormal severity */
      Mu = sbeta(1);
      do i=1 to dim(sx);
         Mu = Mu + sx(i) * sbeta(i+1);
      end;
      lossAmount = exp(Mu) * rand('LOGNORMAL')**Sigma;
      loglossAmount = log(lossAmount);

      deductible = lossAmount * rand('UNIFORM');
      if (rand('UNIFORM') < 0.25) then
         limit = lossAmount;

      output;
   end;
run;

data mycas.losses;
   set losses;
run;

proc sevselect data=mycas.losses outest=mycas.est print=all;
   loss lossAmount / lt=deductible rc=limit;
   class carType gender education;
   scalemodel carType gender carSafety income education*carType
              income*gender carSafety*income;
   selection;
   dist logn burr weibull;
   output out=mycas.score copyvars=(carType gender education carSafety income)
          functions=(mean) quantiles=(points=0.5 0.975 names=(median var));
run;

data score;
   set mycas.score(obs=10);
run;

proc print data=score noobs;
   var logn_mean burr_mean weibull_mean
       carType gender education carSafety income;
run;

proc print data=score noobs;
   var logn_median burr_median weibull_median
       carType gender education carSafety income;
run;

proc print data=score noobs;
   var logn_var burr_var weibull_var
       carType gender education carSafety income;
run;



