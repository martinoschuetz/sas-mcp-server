

libname a "D:\DATEN\FORECAST";

data a.telkodata;
  set a.telkodata;
  where zeitstempel<'01DEC2007'D;
run;


data a.telkodata;
 set a.telkodata a.telko_update;
run;

proc sort data=a.telkodata;
by segment channel tariftyp tarif zeitstempel;run;

