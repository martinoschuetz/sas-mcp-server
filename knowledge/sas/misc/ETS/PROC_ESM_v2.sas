/* Bitte diese Makro-Variablen belegen */

%let library=sashelp;
%let dsn = citimon;
%let dependent=ConB;
%let timestamp=date;
%let interval=MONTH; /* MONTH | WEEK | DAY | QUARTER */
%let lead=12;
%let criterion=RMSE; /* MAPE | RMSE | MAE | RSQUARE */



/* Ab Hier läuft alles automatisch */

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest1 outfor=outfor1 outstat=outstat1;
   id &timestamp interval=&interval;
   forecast &dependent /model=simple;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest2 outfor=outfor2 outstat=outstat2;
   id &timestamp interval=&interval;
   forecast &dependent /model=double;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest3 outfor=outfor3 outstat=outstat3;
   id &timestamp interval=&interval;
   forecast &dependent /model=linear;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest4 outfor=outfor4 outstat=outstat4;
   id &timestamp interval=&interval;
   forecast &dependent /model=damptrend;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest5 outfor=outfor5 outstat=outstat5;
   id &timestamp interval=&interval;
   forecast &dependent /model=seasonal;
run;


proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest6 outfor=outfor6 outstat=outstat6;
   id &timestamp interval=&interval;
   forecast &dependent /model=multseasonal;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest7 outfor=outfor7 outstat=outstat7;
   id &timestamp interval=&interval;
   forecast &dependent /model=winters;
run;

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest8 outfor=outfor8 outstat=outstat8;
   id &timestamp interval=&interval;
   forecast &dependent /model=addwinters;
run;

data outstat_final;
 set outstat1 - outstat8;
 modelnumber=_n_;
 Length modelname $100.;
 if modelnumber=1 then MODELNAME='Simple Exponential Smoothing';
 if modelnumber=2 then MODELNAME='Double Exponential Smoothing';
 if modelnumber=3 then MODELNAME='Linear Exponential Smoothing';
 if modelnumber=4 then MODELNAME='Damped Trend Exponential Smoothing';
 if modelnumber=5 then MODELNAME='(Additive) Seasonal Exponential Smoothing';
 if modelnumber=6 then MODELNAME='(Multiplicative) Seasonal Exponential Smoothing';
 if modelnumber=7 then MODELNAME='(Additive) Winters Method';
 if modelnumber=8 then MODELNAME='(Multiplicative) Winters Method';
 Label modelname='Model Name';

run;

proc sql; create table selectedmodel as select 
modelnumber,
&criterion 
from outstat_final
where &criterion = (select min(&criterion) from outstat_final);
quit;

data _null_;
 set selectedmodel;
 call symput("selmod",modelnumber);
run;
%put selmod=&selmod;
%let number=%str(&selmod);
%put number=&number;

data forecast_final;
 set outfor%eval(&number);
run;

data parameters_final;
 set outest%eval(&number);
run;

data statistics_final;
 set outstat%eval(&number);
run;

proc sql noprint; select max(&timestamp) into:maxdate from &library..&dsn ;
%put date=&maxdate;


title1 "Forecast Results";
proc sgplot data=forecast_final;
   series x=&timestamp y=ACTUAL /lineattrs=(color=red);
   series x=&timestamp y=PREDICT/lineattrs=(color=blue);
   series x=&timestamp y=LOWER /lineattrs=(color=styg);
   series x=&timestamp y=UPPER/ lineattrs=(color=styg);
  refline &maxdate / axis=x;
run;

title1 "Model Fit Statistics";
proc print data=outstat_final(where=(modelnumber=&number)) noobs label;
VAR Modelname AIC SBC MAPE MAE RMSE RSQUARE ;
run;

title1 "Model Parameters";
proc print data=parameters_final noobs label;
VAR _ALL_;
run;

title1;


proc datasets library=work nolist;
   delete outfor1 - outfor8 outstat1 - outstat8 outest1 - outest8 selectedmodel / memtype=data;
quit;
