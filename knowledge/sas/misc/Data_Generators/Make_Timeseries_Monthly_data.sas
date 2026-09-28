
libname a "D:\DATEN\QUELLEN";



data jahr;
do i=1 to 6;
  jahr=2002+i;
  jf_1=1+((i-1)**2)/12;
  jf_2=1/(i/2);
  jf_3=1+rannor(312)/4;
  output;
end;
drop i;
run;

data monat;
 do monat=1 to 12;
 mf_1=1+sin(monat+60)/2; if monat in (1,6,7,8) then mf_1=sqrt(mf_1);
 mf_2=1+cos(monat/2)/5;
 mf_3=1+sin(monat/2)/2;
 output;
 end;
run;

data gruppe1;
 do gruppe1=1 to 20;
 baseline=abs(int(ranexp(25245)*100000));
 if gruppe1 in (2,3,4) then trend=1;
 else if gruppe1 in (8,12,14,15,16) then trend=2;
 else trend=3;
 if gruppe1 in (1,2,4,8,6,12,14,20) then saison=1;
 else if gruppe1 in (5,6,7,13,17) then saison=2;
 else saison=3;

 pf=1+rannor(123)*0.4;
 output;
 end;
run;

data gruppe0;
 do gruppe0=1 to 7;
 kf=ranuni(451);
  output;
  end;
  run;

 data segment;
  do seg=1 to 3;
     if seg=1 then segf=0.67;
	 else if seg=2 then segf=0.14;
	 else if seg=3 then segf=0.29;
  output;
  end;
run;

proc sql;
create table basetable as select 
a.*, b.*, c.*, d.*,e.* from jahr a, monat b, gruppe1 c, gruppe0 d, segment e
order by seg, gruppe0, gruppe1, jahr, monat;
quit;

data basetable;
 set basetable;
 zeitstempel=mdy(monat,1,jahr); 
 format zeitstempel monyy.;
 if trend=1 then jf=jf_1; else if trend=2 then jf=jf_2; else jf=jf_3;
 if saison=1 then mf=mf_1;else if saison=2 then mf=mf_2;else mf=mf_3;

 marketing=100+rannor(321)*20;
 if gruppe1 in (5,7,9,10,11,13,17,18,19) and zeitstempel in 
    ('01JUN2005'd,'01JUL2005'd,'01AUG2005'D,'01DEC2007'D) then marketing=marketing*(2.5+ranuni(432)/10);
 else if gruppe1 in (5,13,17,18,19,20) and zeitstempel in 
    ('01JUN2007'd,'01JUL2007'd,'01AUG2007'D,'01APR2008'D) then marketing=marketing*(2+ranuni(312)/10);
 else if gruppe1 in (8,12,14,15,16) and zeitstempel in 
    ('01FEB2005'd,'01MAR2006'd,'01AUG2006'D,'01MAY2007'D,'01OCT2007'D,'01JUN2008'D) then marketing=marketing*(3+ranuni(51)/10);
 marketing=int(marketing);


 retain counter 1;
 if first.gruppe1 then counter=1;else counter=counter+1;
 x0=(log(baseline*jf*mf*kf));
 x=(x0*10000+rannor(401)*2000+0.5*marketing**2)*segf;
 xlag=lag(x);
 if counter>1 then umsatz=int(0.9*x+0.1*xlag);else umsatz=int(x);
 umsatz=int(umsatz*pf);

 if counter>59 then umsatz=.;
 by seg gruppe0 gruppe1;
run;

data basetable;
 set basetable;
 length tarif $ 40.;
 if gruppe1=1 then tarif='PowerTalk 25';
 else if gruppe1=2 then tarif='PowerTalk 50';
 else if gruppe1=3 then tarif='UMTS Power';
 else if gruppe1=4 then tarif='UMTS Basic';
 else if gruppe1=5 then tarif='FunTalk 25';
 else if gruppe1=6 then tarif='FunTalk 50';
 else if gruppe1=7 then tarif='FunTalk 150';
 else if gruppe1=8 then tarif='Flexi Happy Web';
 else if gruppe1=9 then tarif='Flexi Professional';
 else if gruppe1=10 then tarif='Flexi Family&Friends';
 else if gruppe1=11 then tarif='Flexi Student';
 else if gruppe1=12 then tarif='Flexi Basic';
 else if gruppe1=13 then tarif='Flexi Extra';
 else if gruppe1=14 then tarif='Clever & Smart 120';
 else if gruppe1=15 then tarif='Clever & Smart 60'; 
 else if gruppe1=16 then tarif='Clever & Smart 30';
 else if gruppe1=17 then tarif='Flatfone Base';
 else if gruppe1=18 then tarif='Flatfone Double';
 else if gruppe1=19 then tarif='Flatfone Triple';
 else if gruppe1=20 then tarif='Flatfone Value';
 length channel $ 30.;
 if gruppe0=1 then channel='Eigene Shops';
 else if gruppe0=2 then channel='Webseite';
 else if gruppe0=3 then channel='Callcenter';
 else if gruppe0=4 then channel='Vertragspartner';
 else if gruppe0=5 then channel='Retail';
 else if gruppe0=6 then channel='Groﬂkunden';
 else if gruppe0=7 then channel='Home Shopping TV';
 length tariftyp $ 20.;
 if gruppe1 in (1,2) then tariftyp='PowerTalk';
 else if gruppe1 in (3,4) then tariftyp='UMTS';
 else if gruppe1 in (5,6,7) then tariftyp='FunTalk';
 else if gruppe1 in (8,9,10,11,12,13) then tariftyp='Flexi';
 else if gruppe1 in (14,15,16) then tariftyp='Clever & Smart';
 else if gruppe1 in (17,18,19,20) then tariftyp='Flatfone';
 length segment $ 30;
 if seg=1 then segment='Consumer';
 else if seg=2 then segment='SOHO';
 else if seg=3 then segment='Business';

 label zeitstempel='Monat' 
       channel='Vertriebsgruppe0' 
       tarif='Tarif'
       tariftyp='Tariftyp'
       umsatz='Umsatz' 
      marketing='Marketing-Budget'
       segment='Kundensegment';
run;


proc sql;
 create table jahresplanwerte as select
 distinct jahr,
 seg,
 gruppe1,
 gruppe0,
 avg(umsatz) as sum_umsatz
 from basetable
 group by jahr, seg, gruppe0, gruppe1
 order by gruppe1, gruppe0, seg, jahr
 ;
 quit;

data jahresplanwerte;
 set jahresplanwerte;
 lagumsatz=lag(sum_umsatz);
 if missing(sum_umsatz) then sum_umsatz=int(lagumsatz*1.01);
 drop lagumsatz;
run;

proc sql;
create table basetable as select
a.*,
a.mf**0.20 as mpf,
int(b.sum_umsatz*(a.mf**0.20)) as planwerte
from basetable a, jahresplanwerte b
where a.gruppe0=b.gruppe0 and a.gruppe1=b.gruppe1 and a.jahr=b.jahr and a.seg=b.seg
order by segment, channel, tarif, zeitstempel;
quit;

proc sql;
 create table a.telkodata as select 
 Zeitstempel,
 Channel,
 Segment,
 Tariftyp,
 Tarif,
 Umsatz,
 Marketing,
 Planwerte from basetable;
 quit;
proc datasets nowarn nolist lib=work;
delete jahr monat gruppe1 gruppe0 jahresplanwerte segment;
quit;




proc sort data=basetable;
 by channel tarif;
run;

symbol1 interpol=j v=dot color=blue;
symbol2 interpol=j v=star color=red;

ods html;

proc gplot data=basetable (where=(gruppe1 in (1,6,7,20) and channel in ('Shop','Callcenter') and segment='Business'));
   plot (umsatz planwerte)*zeitstempel / overlay;
   by segment channel tarif;
run;
ods html close;

