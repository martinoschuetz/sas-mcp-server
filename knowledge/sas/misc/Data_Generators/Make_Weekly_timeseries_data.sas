/* Test generiere Wochendaten für Abverkäufe */
libname a "D:\DATEN\AS";

%let frequenz=(2*3.14159265358979)/(365.25);



data rawseries;
   i=16000;
   do while (i<today());
       week=i;
	   date=i;
	   i=i+7;
   output;
   end;
   format week weekw5. date date9.;
run;

data skus;
  length artikel $ 50.;
  do i=1 to 10;
  if i=1 then artikel='AS Allesreiniger Konzentrat Frühlingsduft 1L';
  else if i=2 then artikel='AS Allesreiniger Limonen-Frische 1L';
  else if i=3 then artikel='Ajax Allzweckreiniger Citrus 1L';
  else if i=4 then artikel='Frosch Zitronen-Scheuermilch 250ml';
  else if i=5 then artikel='Mr. Proper Multispray Citrusfrische 500ml';
  else if i=6 then artikel='Sagrotan 4in1 Allzweckreiniger Meeresfrisch 1,25L';
  else if i=7 then artikel='Frosch Allzweckreiniger-Konzentrat Orange 500ml';
  else if i=8 then artikel='Sagrotan Neutralreiniger 250 ml';
  else if i=9 then artikel='Ajax Allzweckreiniger Neutral 1L';
  else if i=10 then artikel='Sidol Reiniger Zitronenkraft 1L';
  output;
  end;
  drop i;
run;

data filialcluster;
  length cluster $ 20.;
  do i=1 to 8;
  if i=1 then cluster='Cluster 1';
  else if i=2 then cluster='Cluster 2';
  else if i=3 then cluster='Cluster 3';
  else if i=4 then cluster='Cluster 4';
  else if i=5 then cluster='Cluster 5';
  else if i=6 then cluster='Cluster 6';
  else if i=7 then cluster='Cluster 7';
  else if i=8 then cluster='Cluster 8';
  output;
  end;
  drop i;
run;

proc sql;
 create table temp1 as select
 a.cluster,
 b.artikel
 
 from filialcluster a, skus b
 order by cluster, artikel;
quit;

data temp1; set temp1;
  amplitude=int((12+rannor(321)*3));
  shift=int(40+ranuni(1)*4-2);
  basesale=int(400+rannor(3)*70);
  unique_id=_N_;
run;

proc sql;
 create table temp2 as select 
 a.*,
 b.i,
 b.date,
 b.week
 from temp1 a, rawseries b
 order by cluster, artikel, date;
 quit;
 
data temp2;
 set temp2;
   if first.unique_id then do;
   autocorr=0;
   output;
   end;
   else do;
   retain autocorr 0;
   weekly=amplitude*cos(&frequenz*(i-shift))+amplitude*sin(&frequenz*(i-shift));
   random=rannor(1)*13;
   trend=i/100;
   sales=int(0.5*(basesale+trend+weekly+random)+0.5*autocorr);output;
   autocorr=sales;
   end;
  by unique_id;

 
run;

data temp2;
 set temp2;
 if date<'01APR2004'd then delete;
 run;

ODS HTML;

%let auswahl=Cluster 1;

goptions device=activex;
axis2 label=("Zeitraum" );
symbol1 color=blue
        interpol=join
        value=none
        height=1;

title1 "Fiktive Zeitreihe";
proc gplot data=temp2 (where=(cluster="&auswahl"));
plot  sales * date = 1/haxis=axis2;
by artikel;
run;
quit;

ODS HTML close;

libname fc "D:\DATEN\FORECAST";
  data fc.detergents_weekly;
   set temp2;
   drop amplitude shift basesale unique_id autocorr i weekly random trend week; 
run;
