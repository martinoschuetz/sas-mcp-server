
/* stp für Data Retrieval */

%let _ODSSTYLE=meadow;


*ProcessBody;
%stpbegin;

%global catselect;

/*%let catselect=Salzgebäck;*/

libname fc "C:\SAS\ForecastStudio\Projects\SASFoods\hierarchy\Product";
libname a "D:\DATEN\Forecast";

proc sql;
 create table A.temp as select
 outfor.category as category,
 outfor.productgroup as productgroup,
 outfor.product as product,
 outfor.date as date label='Monat',
 outfor.actual as actual label='Ist-Werte' format comma8.0,
 outfor.predict as predict label='Statistische' format comma8.0,
 outfor.lower as lower label='Prognose_Untergrenze' format comma8.0,
 outfor.upper as upper label='Prognose_Obergrenze' format comma8.0,
 snacks4.camptext as camptext
 from fc.outfor left join a.snacks4
 on outfor.date=snacks4.date and outfor.product=snacks4.product
 order by category, productgroup,product, date;
quit;



data a.temp;
     set a.temp;
	 if actual >0 then delta=((predict-actual)/actual)*100; else delta=0;
	 final=predict;
     format final 8.0 delta 8.2;
     label final='Finale_Prognose' delta='Delta_in_%';
run;

title;
proc print data=fc.temp (where=(category ="&catselect")) noobs ;
  var category productgroup product camptext date actual predict delta final;
run;






%stpend;
