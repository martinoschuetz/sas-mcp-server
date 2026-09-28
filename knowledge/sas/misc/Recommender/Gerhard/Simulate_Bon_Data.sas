/* Pfad für Ablage der Rohdaten (CSV-Dateien) */
%let fpath=C:\Codes\Recommender\Gerhard;


/* Pfad für Speicherort der Pre-Assigned Library */
libname outlib "C:\Codes\Recommender\output";


/* Importiere Rohdaten und bereite sie auf */
DATA tmp1;
    LENGTH
        F1               $ 15
        F2               $ 86
        F3               $ 87
        F4               $ 84
        F5               $ 7
        F6               $ 21
        F7               $ 7
        F8               $ 1 ;
    FORMAT
        F1               $CHAR15.
        F2               $CHAR86.
        F3               $CHAR87.
        F4               $CHAR84.
        F5               $CHAR7.
        F6               $CHAR21.
        F7               $CHAR7.
        F8               $CHAR1. ;
    INFORMAT
        F1               $CHAR15.
        F2               $CHAR86.
        F3               $CHAR87.
        F4               $CHAR84.
        F5               $CHAR7.
        F6               $CHAR21.
        F7               $CHAR7.
        F8               $CHAR1. ;
    INFILE "&fpath\Baumarkt_2.dat"
        LRECL=1024
        ENCODING="WLATIN1"
        TERMSTR=CRLF
        DLM=';'
        MISSOVER
        DSD ;
    INPUT
        F1               : $CHAR15.
        F2               : $CHAR86.
        F3               : $CHAR87.
        F4               : $CHAR84.
        F5               : $CHAR7.
        F6               : $CHAR21.
        F7               : $CHAR7.
        F8               : $CHAR1. ;
RUN;


data tmp2;
  set tmp1;

  
  ARTNAME=f2;
  
  KATEGORIE=scan(f3,1,'>');
  HAUPTGRUPPE=scan(f3,2,'>');
  UNTERGRUPPE=scan(f3,3,'>');



  PREIS_REG=input(f4,6.2);
  if PREIS_REG>5 then PREIS_REG=PREIS_REG+int(ranuni(23123))*5-2.5;
  drop f1 f2 f3 f4 f5 f6 f7 f8;
  if missing(PREIS_REG) then delete;
run;

data tmp3; 
 set tmp2;
 
 KATEGORIE=strip(KATEGORIE);
 HAUPTGRUPPE=strip(HAUPTGRUPPE);
 UNTERGRUPPE=strip(UNTERGRUPPE);
 UID=_n_;
run;

proc sort data=tmp3 out=tmp4;
  by KATEGORIE HAUPTGRUPPE UNTERGRUPPE;
run;

data tmp5;
 set tmp4;

 retain KATNO HGNO UGNO;
 if first.KATEGORIE then KATNO+1;
 if first.HAUPTGRUPPE then HGNO+1;
 if first.UNTERGRUPPE then UGNO+1;


 by KATEGORIE HAUPTGRUPPE UNTERGRUPPE;

 KAT_KEY=KATNO;
 HG_KEY=KATNO*1000+HGNO;
 UG_KEY=KATNO*100000+HGNO*1000+UGNO;

 ARTNO=UG_KEY*10000000+_n_;
 format ARTNO 16.0;
 
run;


/* Selektiere Artikel und generiere künstliche Häufigkeiten pro Artikel (abhängig von Preis)*/
data tmp6; 
set tmp5;
where ranuni(344)<0.5 or UNTERGRUPPE in 
   ('Außenleuchten', 
    'Sonnenschirme und -segel',
	'Grill-Zubehör',
	'Holzkohlegrills',
    'Rasentrimmer und Sensen',
    'Garten- und Baumscheren',
    'Benzin-Rasenmäher',
	'Pflanztöpfe, -kübel und -schalen'
);
if      preis_reg<10 then freq=300+int(rangam(1234,12)*6);
else if preis_reg<50 then freq=60+int(rangam(2345,5)*4);
else                      freq=10+int(ranpoi(3456,5));

/* Hier künstliche Häufigkeiten für Verbundkauf mit Aktionsartikel Deutschland-Flagge einfügen */
if uid in (599, 4708, 6531, 220) then freq=300-int(ranuni(4567)*10);


/* Hier sonstige künstliche Häufigkeiten für Verbundkauf einfügen */
if uid in (1947, 
          6898, 
          4566, 
          2160, 
          9273, 
          8269, 
          4767, 
          5380, 
          8280, 
          3154, 
          6686, 
          6730, 
          7693,
          7107,
		  2047,
		  6013,
		  2764,
		  5450


) then freq=500+ranpoi(1234,2);

ARTNAME=cat('Art.Nr.',put(UID,z5.0),' ', ARTNAME);

lfd=_n_;

run;

proc sql noprint; select count(*) into:maxobs from tmp6;quit;


/* Generiere Basis-Tabelle für Transaktionen (aus Häufigkeiten)*/
data tmp7;
  set tmp6;
  
  do i = 1 to &maxobs;
  do j=1 to 600;
   if i =1 and j<=freq then output; else delete;
   end;

  end;

  


run;

/* Zufällige Sortierung */
data tmp8;
 set tmp7;
  ransel=ranuni(111);
   drop i j;
run;

proc sort data=tmp8;
by ransel;
run;

data tmp9;
  set tmp8;

  retain xxx_id 0;

  if ranuni(123) > 0.6 then xxx_id+1;
  format xxx_id z8.0;

  drop freq ransel;

  /*flag für HG Bodenbeläge */
  if hgno=8 then flg=1; else flg=0;
run;



proc sql; create table tmp10 as select
distinct (xxx_id) as xxx_id,
sum(flg) as sumflg
from tmp9
group by xxx_id;
quit;



data tmp11;
 set tmp10;
 x1=ranuni(7);
 x2=ranuni(8);
 x3=ranuni(9);

 /* Datum fixieren */
 DATUM='02MAY2012'D+int(ranuni(235)*31);
 y=ranpoi(2,2)*4;
 if DATUM>'01JUN2012'D then DATUM='01JUN2012'D-y;
 
 if DATUM='01MAY2012'D then DATUM=DATUM+1+int(ranuni(232)*5);

 z=ranuni(1);
 if weekday(DATUM)=1 and z<0.7 then DATUM=DATUM-1;
 if weekday(DATUM)=1 and z>=0.7 then DATUM=DATUM-2;
 
 format DATUM date9.;
 

 /* Uhrzeit (Bodenbeläge morgens !) */
 if sumflg=1    then UHRZEIT=3600*8 +int(ranuni(434)*1000);
 else if x1<0.3 then UHRZEIT=3600*8+int(ranuni(434)*3600*4);
 else if x1<0.5 then UHRZEIT=3600*8+int(ranuni(434)*3600*6);
 else                UHRZEIT=3600*8+int(ranuni(434)*3600*12);
 format UHRZEIT time.;

 FID=int(ranuni(4)*30)+1;
 if x2<=0.7 then FID=4+int(ranuni(3)*18);
 if x3>=0.8 then FID=20+int(ranuni(22)*3);


 drop x1 x2 x3 y z;
 run;
proc sql noprint; select max(FID) into: maxfil from tmp11;quit;

/* Geo-Daten einspielen */

data tmp12;
 infile "&fpath\PLZ.TXT" DELIMITER='09'x MISSOVER DSD;
 input
 Primaerschluessel : $5.
 PLZ : $5.
 LAENGENGRAD : 8.
 BREITENGRAD : 8.
 FILIALE : $40.;
  y=_n_;
 if y not in (18,1560,1431, 2079,2213,2449,2954, 3024, 3161, 3404,3600,3655,3882,4276,4458, 4603, 4888, 4920,4973,
               5550, 5744,5806,5956,6400, 7100,7928, 8189, 148,1106,680) then delete;
  drop primaerschluessel y;
run;

/* Selektiere bestimmte Filialnummern */

 data tmp13;
  set tmp12;
  FID=_n_;
  
  length REGION $12.;
  if Filiale in ('Dresden','Cottbus','Berlin','Rostock','Magdeburg','Erfurt') then REGION='Ost';
  if Filiale in ('Hamburg','Bremen','Kiel','Hannover') then REGION='Nord';
  if Filiale in ('Bielefeld','Düsseldorf','Dortmund','Aachen', 'Münster', 'Köln') then REGION='NRW';
  if Filiale in ('Mainz','Frankfurt am Main','Darmstadt','Mannheim', 'Karlsruhe', 'Stuttgart',
                  'Heidelberg','Konstanz', 'Freiburg im Breisgau', 'Saarbrücken') then REGION='Südwest';
  if Filiale in ('München','Würzburg','Nürnberg','Ingolstadt') then REGION='Bayern';
run;


proc sql; create table tmp14 as select
a.xxx_id,
a.DATUM,
a.UHRZEIT,
b.FILIALE,
b.REGION,
b.LAENGENGRAD,
b.BREITENGRAD
from tmp11 as a left join tmp13 as b on a.FID=b.FID
order by a.xxx_id;
quit;

proc sql; create table tmp15 as select
a.xxx_id,
b.DATUM,
b.UHRZEIT,
b.FILIALE,
b.REGION,
b.LAENGENGRAD,
b.BREITENGRAD,
a.ARTNO,
a.ARTNAME,
a.KATEGORIE,
a.HAUPTGRUPPE,
a.UNTERGRUPPE,
a.PREIS_REG,
a.UID
from tmp9 as a left join tmp14 as b on a.xxx_id=b.xxx_id;
quit;

data tmp16;
 set tmp15;
 if ranuni(44)<0.8 then ANZ_VE=1; else ANZ_VE=ranpoi(3,2)*2+1;

 /* Promotions einbauen */
 if ranuni(111)<0.03 then do;
    if ranuni(41) >0.5 then ANZ_VE=ANZ_VE*2;
	if ranuni(44)>0.5 then PREIS_PROMO=round(PREIS_REG*0.66,0.99);
	else PREIS_PROMO=round(PREIS_REG*0.5,0.99);
	
	AKTION=1;
 end;
 else do ; 
    AKTION=0;
	PREIS_PROMO=PREIS_REG;
 end;

 NETTOUMSATZ=PREIS_PROMO*ANZ_VE;
 format NETTOUMSATZ 8.2;





 label ARTNAME='Artikelbezeichnung'
       ARTNO='Artikelnummer'
	   KATEGORIE='Warenkategorie'
	   HAUPTGRUPPE='Artikelhauptgruppe'
	   UNTERGRUPPE='Artikeluntergruppe'
	   PREIS_REG='VK-Preis (regulär)'
	   PREIS_PROMO='VK-Preis (Promotion)'
	   DATUM='Datum'
	   UHRZEIT='Zeitstempel'
	   FILIALE='Filiale'
	   REGION='Vertriebsregion'
	   ANZ_VE='Anzahl VE'
	   LAENGENGRAD='Längengrad'
	   BREITENGRAD='Breitengrad'
	   AKTION='Flag für Aktionsartikel'
	   NETTOUMSATZ='Nettoumsatz'
;


run; 


/* Zusätzlichen Artikel WM Flagge einfügen*/
data tmp17; 
set tmp16;
where uid in (599, 4708, 6531, 220) and ranuni(1232)<0.9;
 
ARTNAME ='Art.Nr.09999 Deutschland-Fahne 2.0m x 1.5m';
KATEGORIE='Garten & Balkon';
HAUPTGRUPPE='Balkon & Terasse';
UNTERGRUPPE='Trendartikel';
ARTNO=9999999999999;
PREIS_REG=13.99;
PREIS_PROMO=10.99;
AKTION=1;
if ranuni(123)<0.9 then ANZ_VE=1; else ANZ_VE=1+ranpoi(123,2);
NETTOUMSATZ=ANZ_VE*PREIS_PROMO;


run;



/* Generiere daten für zusätzliche ARtikel */

data tmp18;
  set tmp16;
  where UID in  (1947, 4566, 2160, 9273, 8269, 4767, 5380, 8280, 3154, 6686, 6730, 6898, 7693, 7107,2047,6013, 2764,5450);

  x=ranuni(11111);

  /* Hier Regeln für künstliche Verbundkäufe einfügen */
  if x>0.29 and uid=1947 then uid2=4566;
  if x>0.18 and uid=2160 then uid2=9273;
  if x<0.83 and uid=6898 then uid2=8269;
  if x>0.42 and uid=4767 then uid2=5380;
  if x<0.64 and uid=8280 then uid2=3154;
  if x<0.93 and uid=6686 then uid2=6730;
  if x>0.52 and uid=7693 then uid2=7107;
  if x>0.44 and uid=2047 then uid2=6013;
  if x>0.11 and uid=2764 then uid2=5450;


  if uid2=. then delete;

  keep xxx_id DATUM UHRZEIT FILIALE REGION LAENGENGRAD BREITENGRAD UID2 UID;
run;

proc sql; create table tmp19 as select 
a.xxx_id,
a.uid2,
b.uid,
a.DATUM,
a.UHRZEIT,
a.FILIALE,
a.REGION,
a.LAENGENGRAD,
a.BREITENGRAD,
b.ARTNO,
b.ARTNAME,
b.KATEGORIE,
b.HAUPTGRUPPE,
b.UNTERGRUPPE,
b.PREIS_REG
from tmp18 as a left join tmp6 as b on a.uid2=b.uid;
quit;

data tmp20; 
set tmp19;
if ranuni(44)<0.8 then ANZ_VE=1; else ANZ_VE=1+ranpoi(3,2)*2+1;

 /* Promotions einbauen */
 if ranuni(111)<0.03 then do;
    if ranuni(41) >0.5 then ANZ_VE=ANZ_VE*2;
	if ranuni(44)>0.5 then PREIS_PROMO=round(PREIS_REG*0.66,0.99);
	else PREIS_PROMO=round(PREIS_REG*0.5,0.99);
	
	AKTION=1;
 end;
 else do ; 
    AKTION=0;
	PREIS_PROMO=PREIS_REG;
 end;

 NETTOUMSATZ=PREIS_PROMO*ANZ_VE;
 format NETTOUMSATZ 8.2;
run;


data tmp21;
 set tmp16 tmp17 tmp20;


 /* Künstliche Käufe für Aktionsartikel */

 if ranuni(5678)>0.99 then do;
ARTNAME ='Art.Nr. 09999 Deutschland-Fahne 2.0m x 1.5m';
KATEGORIE='Garten & Balkon';
HAUPTGRUPPE='Balkon & Terasse';
UNTERGRUPPE='Trendartikel';
ARTNO=9999999999999;
PREIS_REG=13.99;
PREIS_PROMO=10.99;
AKTION=1;
if ranuni(123)<0.9 then ANZ_VE=1; else ANZ_VE=1+ranpoi(123,2);
NETTOUMSATZ=ANZ_VE*PREIS_PROMO;

end;

 drop uid;
run;


proc sort data=tmp21;
by xxx_id ARTNO;
run;


data tmp22;
 set tmp21;
 ransel=ranuni(1111);
 
/* Dubletten herausnehmen */
if xxx_id=lag(xxx_id) and ARTNO=lag(ARTNO) then delete;
 run;

proc sort data=tmp22 out=tmp23;
 by datum xxx_id ransel;
run;

/* Erstellen der finalen Tabelle */
data BONDATEN_BAUMARKT;
 set tmp23;

 PREIS_EK = PREIS_REG * (0.6+ranuni(222)/5);
 format PREIS_EK 8.2;
 

 TRANS_ID=500000000+int(ranuni(123))*9999999+xxx_id;

 if first.xxx_id then do;
     BONPOSITION=1;
 end;
 else do;
    BONPOSITION+1;
 end;





 label BONPOSITION = "Bon-Position"
 	   TRANS_ID ="Transaktions-ID"
	   PREIS_EK = "EK-Preis";
 by datum xxx_id ransel;
 drop xxx_id ransel uid2;
run;




/* Cross Tab sicht */

proc sql; create table tmp24 as select
distinct a.ARTNAME label "Artikel 1" as ARTIKEL1,
		 a.KATEGORIE label "Warenkategorie 1" as KATEGORIE1,
		 a.HAUPTGRUPPE label "Hauptgruppe 1" as HAUPTGRUPPE1,
		 a.UNTERGRUPPE label "Untergruppe 1" as UNTERGRUPPE1,
		 sum(a.NETTOUMSATZ) label "Nettoumsatz 1" as NETTOUMSATZ1,
		 sum(a.AKTION) label "Anzahl Aktionen 1" as ANZ_AKTIONEN1,

         b.ARTNAME label "Artikel 2" as ARTIKEL2,
		 b.KATEGORIE label "Warenkategorie 2" as KATEGORIE2,
		 b.HAUPTGRUPPE label "Hauptgruppe 2" as HAUPTGRUPPE2,
		 b.UNTERGRUPPE label "Untergruppe 2" as UNTERGRUPPE2,
		 sum(b.NETTOUMSATZ) label "Nettoumsatz 2" as NETTOUMSATZ2,
		 sum(b.AKTION) label "Anzahl Aktionen 2" as ANZ_AKTIONEN2,
		  

        count(distinct a.TRANS_ID) label "Anzahl Transaktionen" as ANZAHL_TRANS,

		(sum(a.Nettoumsatz)+sum(b.NETToumsatz)) label "Nettoumsatz" as NETTOUMSATZ
from BONDATEN_BAUMARKT as a left join BONDATEN_BAUMARKT as b on a.TRANS_ID=b.TRANS_ID 
     where lengthn(a.ARTNAME)>0 and lengthn(b.ARTNAME)>0

group by a.ARTNAME, b.ARTNAME;
quit;



data BONDATEN_BAUMARKT_CROSSTAB;
 set tmp24;
 if ARTIKEL1 = ARTIKEL2 then delete;
run;



proc copy in=work out=outlib;
select BONDATEN_BAUMARKT BONDATEN_BAUMARKT_CROSSTAB;
run;
