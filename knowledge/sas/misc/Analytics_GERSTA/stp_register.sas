
*ProcessBody;
%stpbegin;

options nosymbolgen;

/*
%let pfad=D:\DATEN\FORECAST\RESULTS;
%let datei=prognose1.xls;
%let tabelle=Final;
*/



data _null_;
  /*call system("Del D:\DATEN\FORECAST\Results\backup.xls");*/
  call system("copy &pfad\&datei D:\DATEN\Forecast\Results\backup.xls");
run;

libname fcr "D:\DATEN\FORECAST\Results";

proc import datafile="D:\DATEN\Forecast\Results\backup.xls" out=fcr.prognose_final;
      sheet="&tabelle";
      getnames=yes;
run;
 
ODS HTML;


title "Prognosen auf Server aktualisiert am %SYSFUNC(TODAY(), eurdfdd8.) um %SYSFUNC(TIME(), TIME5.) Uhr";

DATA a;
 length status $ 30;
 status= 'erfolgreich!';
 label status = "Status";
run;

proc print data=a noobs label;
var _ALL_;run;
  

ODS HTML close;
%stpend;
