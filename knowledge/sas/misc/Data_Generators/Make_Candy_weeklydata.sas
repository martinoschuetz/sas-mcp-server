data tmp;
set daten.candybars;
datum=intnx('Day',date,(365*3-13));
drop event feiertag date;
format datum date9.;
run;

%include "C:\SONSTIGES\SASCODE\Make_Calender_Events_Until_2020.sas";


proc sql; create table tmp2 as select
a.*,
b.event,
b.wochentag, 
b.total_flag as holiday
from tmp as a left join tageskalender as b on
a.datum=b.datum
order by a.category, a.productgroup, a.product,a.datum;
quit;

proc timeseries data=tmp2 out=tmp3;
   by category productgroup product;
   id datum interval=week format=weeku6.
                accumulate=median
                setmiss=0
                start='15MAR2009'd
                end  ='31DEC2011'd;
   var sales /accumulate=total;
   var holiday price /accumulate=maximum;
run;


proc means data=tmp3(where=(sales>0)) noprint;
 var sales;
 output out=tmp4 mean=;
 by category productgroup product;
 run;

 proc sql; create table tmp5 as select
 a.*,
 b.sales as sales_mean
 from tmp3 as a left join tmp4 as b on (a.category=b.category and a.productgroup=b.productgroup and a.product=b.product)
 order by a.category, a.productgroup, a.product,a.datum;
 quit;

 data tmp6;
   set tmp5;
   pct_chg= sales/(lag(sales))-1;
   if first.product then pct_chg=.;

   by category productgroup product;

   if pct_chg>2 then promo1=1; else promo1=0;

   pct_chg2=sales/sales_mean;

   if pct_chg2>1.5 then promo2=1; else promo2=0;

   drop pct_chg2 pct_chg ;

   if promo2=1 then promotion=1;else promotion=0;
run;

data daten.Candybars_Weekly;
set tmp6;run;