

 
%include "D:\DataSave\mywork\programme\create_events.sas";

data temp1;
 do datum=today()-365*2 to today()+30;
  output;
  end;
  format datum date9.;
run;

proc sort data=temp1;
 by datum;
run;

data temp2;
  length produkt $12.;
 do p=1 to 24;
   produkt='Produkt '||trim(put(p,2.));
   if p<=5 then segment='Segment 1';
   else if p<=12 then segment='Segment 2';
   else segment='Segment 3';
 output;
 end;
 drop p;
run;

proc sql;
  create table temp3 as select
  a.*,
  b.* 
  from temp1 a, temp2 b;quit;

  data temp3;
   set temp3;
   if first.produkt then laufzeit=1;
   else laufzeit+1;
   by produkt;
run;

data temp3;
 set temp3;
   if weekday(datum)=1 then delete;
retain test ;
if first.produkt then test=0;
if mod(laufzeit,int(12+ranuni(435)*4)-2)=0 then do;
   test=1;
   ausstoss=abs(int(55000+rannor(3254)*30000));
   
end;
else do;
test=0;
ausstoss=0;
end;
by produkt;

if _N_=1 then ausstoss=60000;
run;
/*
data temp4;
 set temp3;
 retain absatz;
 if test=1 or _N_=1 then absatz=int(0.04443*ausstoss+ranpoi(4124,5));
 else absatz=int(absatz*decay)+ranpoi(3213,3);
run;*/

data temp4; 
set temp3; 

retain x 0 shape 3;


if test=1 then do;
  x=1; 
 shape=2+int(ranuni(4324324)*3);
end;
else do;
   x=x+1;
   shape=shape;
end;
 
y=cdf('GAMMA',x,shape);
y2=y-lag(y);if test=1 or _N_=1 then y2=y; format y2 8.2; drop y;

retain absatz;
  if ausstoss>0 then absatz=ausstoss/100;
  else absatz=absatz;


  by produkt;
  
  bestellungen=absatz*y2+ranuni(432)*10-5;
  if bestellungen<=0 then bestellungen=ranpoi(23456,3); 


format bestellungen 8.0;

run;

proc sql;
 create table temp5 as select
 a.*,
 b.flag1,
 b.flag2,
 b.flag3
 from temp4 a left join feiertage b on (a.datum=b.datum)
 order by produkt, datum;
 quit;

 data temp5;
   set temp5;
   lagflag=lag(flag1);
   if flag1=1 then bestellungen=0;
    if lagflag=1 then bestellungen=3*bestellungen;

  feiertag=flag1;
  if datum>today() then bestellungen=.;
  if datum=today()+int(ranuni(432543)*30) then ausstoss=int(55000+rannor(3254)*30000);


run;


data fcslib.catalog;
 set temp5;

 drop decay test laufzeit shape x y2 absatz lagflag flag1--flag3;
 if flag1 =0 then adjust=1; else if flag1=1 then adjust=0;

 label datum='Datum'
       produkt='Produkt'
       bestellungen='Bestellmengen'
       ausstoss='Ausstoﬂ (Auflage)'
       segment='Kundensegment'
       feiertag='Feiertag';


 run;