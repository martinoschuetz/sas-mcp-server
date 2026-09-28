/* Bitte diese Makro-Variablen belegen */

%let library=sashelp;
%let dsn = citimon;
%let dependent=ConB;
%let timestamp=date;
%let interval=MONTH; /* MONTH | WEEK | DAY | QUARTER */
%let lead=12;
%let criterion=RMSE; /* MAPE | RMSE | MAE | RSQUARE */
%let model=LINEAR; /* SIMPLE | DOUBLE | LINEAR | DAMPTREND | SEASONAL | MULTSEASONAL | WINTERS | ADDWINTERS



/* Ab Hier läuft alles automatisch */

proc esm data=&library..&dsn lead=&lead out=_NULL_

         outest=outest1 outfor=outfor1 outstat=outstat1;
   id &timestamp interval=&interval;
   forecast &dependent /model=&model;
run;


data outstat_final;
 set outstat1;
 modelnumber=_n_;
 Length modelname $100.;
 modelname ="&model";
 Label modelname='Model Name';

run;

data forecast_final;
 set outfor1;
run;

data parameters_final;
 set outest1;
run;

data statistics_final;
 set outstat1;
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
proc print data=outstat_final noobs label;
VAR Modelname AIC SBC MAPE MAE RMSE RSQUARE ;
run;

title1 "Model Parameters";
proc print data=parameters_final noobs label;
VAR _ALL_;
run;

title1;


proc datasets library=work nolist;
   delete outfor1 outstat1 outest1 / memtype=data;
quit;
