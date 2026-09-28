
*ProcessBody;
%stpbegin;

/*---------------------------------------------------------*/
/*- include the LIBNAME statements for the project        -*/
/*---------------------------------------------------------*/
%include "&HPF_INCLUDE";

/*---------------------------------------------------------*/
/*- print the statistics table for PARENT node            -*/
/*---------------------------------------------------------*/

libname a "D:\DATEN\FORECAST\Results";
libname fc "C:\SAS\ForecastStudio\Projects\&Hpf_project\hierarchy\product";




proc sql;
 create table A.temp as select
 outfor.category as category,
 outfor.productgroup as productgroup,
 outfor.product as product,
 outfor.date as date label='Datum',
 outfor.actual as actual label='Ist-Werte' format comma8.0,
 outfor.predict as predict label='Statistische Prognose' format comma8.0,
 outfor.lower as lower label='Prognose Untergrenze' format comma8.0,
 outfor.upper as upper label='Prognose Obergrenze' format comma8.0
 from fc.outfor 
 order by category, productgroup,product,date;
quit;



data a.temp;
     set a.temp;
	 length comment $40;
	 if actual >0 then delta=((predict-actual)/actual)*100; else delta=0;
	 final=int(predict);
	 predict=int(predict);
	 lower=int(lower);
	 upper=int(upper);
     format final comma8.0 delta 8.2;
     label final='Finale Prognose' delta='Delta in Prozent' comment='Kommentar';
run;

proc sql;
 create table a.prognose_temp as select 
 temp.category as kategorie,
 temp.productgroup as produktgruppe,
 temp.product as produkt,
 temp.date as monat,
 temp.actual as istwerte,
 temp.predict as prognose,
 temp.upper as obergrenze,
 temp.lower as untergrenze,
 temp.delta as delta,
 temp.comment as kommentar,
 temp.final as final
 from a.temp 
 where date>='20Aug2006'd;
quit;

data a.prognose_temp;
  set a.prognose_temp;
  if untergrenze<0 then untergrenze=0;
  format delta 8.2;
run;


title;
proc print data=a.prognose_temp noobs label;
  var kategorie produktgruppe produkt monat istwerte prognose obergrenze untergrenze delta final kommentar;
run;

proc datasets library=a; 
  delete temp /memtype=data;
run;


%stpend;

