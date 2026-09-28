%include "C:\SONSTIGES\SASCODE\Make_calendar_with_Base.sas";

data Branche;
 do i=1 to 16;
    BRANCHE_CODE=i;
	LENGTH BRANCHE_DESC $40.;
	if i= 1 then BRANCHE_DESC="Finanzdienstleistungen";
	if i= 2 then BRANCHE_DESC="Öffentliche Verwaltung, Bundeswehr";
	if i= 3 then BRANCHE_DESC="Land- und Forstwirtschaft";
	if i= 4 then BRANCHE_DESC="Tourismus, Gastronomie";
	if i= 5 then BRANCHE_DESC="IT und Telekommunikation";
	if i= 6 then BRANCHE_DESC="Maschinen- und Anlagenbau";
	if i= 7 then BRANCHE_DESC="Gesundheitswesen, Pflege";
	if i= 8 then BRANCHE_DESC="Einzel- und Grosshandel";
	if i= 9 then BRANCHE_DESC="Medien, Verlagswesen";
	if i=10 then BRANCHE_DESC="Energieversorgung, Chemie";
	if i=11 then BRANCHE_DESC="Bauunternehmen, Rohstoffindustrie";
	if i=12 then BRANCHE_DESC="Hochschulen, Bildungswesen";
	if i=13 then BRANCHE_DESC="Sozialwesen, karitative Einrichtungen";
	if i=14 then BRANCHE_DESC="Transport und Logistik";
    if i=15 then BRANCHE_DESC="Nahrungs- und Genussmittel";
    if i=16 then BRANCHE_DESC="Sonstige";
 output;
 end;
 drop i;
run;


data Arbeitsverhaeltnis;
 do i=1 to 8;
    ARBEITSVERH_CODE=i;
	LENGTH ARBEITSVERH_DESC $40.;
	if i= 1 then ARBEITSVERH_DESC="Selbständig, Freiberuflich";
	if i= 2 then ARBEITSVERH_DESC="Angestellt";
	if i= 3 then ARBEITSVERH_DESC="Im Ruhestand";
	if i= 4 then ARBEITSVERH_DESC="Ausbildung";
	if i= 5 then ARBEITSVERH_DESC="Studium";
	if i= 6 then ARBEITSVERH_DESC="Hausfrau/mann";
	if i= 7 then ARBEITSVERH_DESC="Beamte(r)";
	if i= 8 then ARBEITSVERH_DESC="Sonstige";
output;
 end;
 drop i;
run;




 
DATA Region;
    LENGTH
        F1                 8
        F2               $ 2
        F3               $ 2
        F4               $ 13
        F5               $ 45
        F6               $ 1
        F7               $ 34
        F8                 8
        F9                 8
        F10                8 ;
    FORMAT
        F1               BEST5.
        F2               $CHAR2.
        F3               $CHAR2.
        F4               $CHAR13.
        F5               $CHAR45.
        F6               $CHAR1.
        F7               $CHAR34.
        F8               BEST16.
        F9               BEST16.
        F10              BEST5. ;
    INFORMAT
        F1               BEST5.
        F2               $CHAR2.
        F3               $CHAR2.
        F4               $CHAR13.
        F5               $CHAR45.
        F6               $CHAR1.
        F7               $CHAR34.
        F8               BEST16.
        F9               BEST16.
        F10              BEST5. ;
    INFILE "C:\Sonstiges\SASCODE\GEODATEN.TXT"
        LRECL=512
        DLM=';'
        MISSOVER
        DSD ;
    INPUT
        F1               : ?? BEST5.
        F2               : $CHAR2.
        F3               : $CHAR2.
        F4               : $CHAR13.
        F5               : $CHAR45.
        F6               : $CHAR1.
        F7               : $CHAR34.
        F8               : ?? COMMA16.
        F9               : ?? COMMA16.
        F10              : ?? BEST5. ;
RUN;


data region;
 set region;
 drop f6;
 

 length BUNDESLAND $40.;
      if f3='BY' then BUNDESLAND='Bayern';
 else if f3='BB' then BUNDESLAND='Brandenburg';
 else if f3='BE' then BUNDESLAND='Berlin';
 else if f3='BW' then BUNDESLAND='Baden-Württemberg';
 else if f3='HB' then BUNDESLAND='Bremen';
 else if f3='HE' then BUNDESLAND='Hessen';
 else if f3='HH' then BUNDESLAND='Hamburg';
 else if f3='MV' then BUNDESLAND='Mecklenburg-Vorpommern';
 else if f3='NI' then BUNDESLAND='Niedersachsen';
 else if f3='NW' then BUNDESLAND='Nordrhein-Westfalen';
 else if f3='RP' then BUNDESLAND='Rheinland-Pfalz';
 else if f3='SH' then BUNDESLAND='Schleswig-Holstein';
 else if f3='SN' then BUNDESLAND='Sachsen';
 else if f3='ST' then BUNDESLAND='Sachsen-Anhalt';
 else if f3='TH' then BUNDESLAND='Thüringen';


 rename f1=NUMMER;
 rename f2=STAAT;
 rename f4=BEZIRK;
 rename f5=KREIS;
 rename f7=ORT;
 rename f8=LAENGENGRAD;
 rename f9=BREITENGRAD;

 format f10 z5.0;
 PLZ=vvalue(f10);

 drop f10 f3;

 label f1='Fortlaufende Nummer'
  f2='Staat'
  bundesland='Bundesland'
 f4='Regierungsbezirk'
 f5='Landkreis'
 f7='Stadt, Gemeinde'
 f8='Längengrad'
 f9='Breitengrad'
 plz='Postleitzahl';

 if trim(f4)='-' then f4='';

  if ranuni(2345)<0.1 then delete;

run;

data region;
 set region;
 REGION_ID=_n_;
 drop nummer;
run;

proc sql noprint; select max(region_id)into:maxreg from region; quit;



data rohdaten;
 do i=1 to 500000;
    KUNDEN_ID=i;


	     if ranuni(123)<0.10 then BRANCHE_CODE= 1;
    else if ranuni(123)<0.14 then BRANCHE_CODE= 2;
    else if ranuni(123)<0.15 then BRANCHE_CODE= 3;
    else if ranuni(123)<0.22 then BRANCHE_CODE= 4;
    else if ranuni(123)<0.32 then BRANCHE_CODE= 5;
    else if ranuni(123)<0.41 then BRANCHE_CODE= 6;
    else if ranuni(123)<0.52 then BRANCHE_CODE= 7;
    else if ranuni(123)<0.58 then BRANCHE_CODE= 8;
    else if ranuni(123)<0.60 then BRANCHE_CODE= 9;
    else if ranuni(123)<0.63 then BRANCHE_CODE=10;
    else if ranuni(123)<0.68 then BRANCHE_CODE=11;
    else if ranuni(123)<0.75 then BRANCHE_CODE=12;
    else if ranuni(123)<0.80 then BRANCHE_CODE=13;
    else if ranuni(123)<0.85 then BRANCHE_CODE=14;
    else if ranuni(123)<0.90 then BRANCHE_CODE=15;
    else                          BRANCHE_CODE=16;
 
    
	     if ranuni(567)<0.10 then ARBEITSVERH_CODE= 1;
    else if ranuni(567)<0.50 then ARBEITSVERH_CODE= 2;
    else if ranuni(567)<0.62 then ARBEITSVERH_CODE= 3;
    else if ranuni(567)<0.68 then ARBEITSVERH_CODE= 4;
    else if ranuni(567)<0.73 then ARBEITSVERH_CODE= 5;
    else if ranuni(567)<0.81 then ARBEITSVERH_CODE= 6;
    else if ranuni(567)<0.96 then ARBEITSVERH_CODE= 7;
    else                          ARBEITSVERH_CODE= 8;
    
 
    REGION_ID=int(ranuni(123455)*&maxreg+1);

	if ARBEITSVERH_CODE=6 then BRANCHE_CODE=16;


 output;
 end;
 drop i;
run;

proc sql; create table Basis as select 
a.*,
b.BRANCHE_DESC,
c.ARBEITSVERH_DESC,
d.PLZ,
d.ORT,
d.LAENGENGRAD,
d.BREITENGRAD,
d.BUNDESLAND
from rohdaten as a 
left join branche as b on a.branche_code=b.branche_code
left join arbeitsverhaeltnis as c on a.arbeitsverh_code=c.arbeitsverh_code
left join region as d on a.region_id=d.region_id;
quit;

data Basis2;
 set Basis;
 KUNDENALTER=int(45+rannor(5555)*10);
 if ARBEITSVERH_CODE=3 and KUNDENALTER<65 then KUNDENALTER=65+int(rannor(123)*5);
 if ARBEITSVERH_CODE in (4,5) and KUNDENALTER>25 then KUNDENALTER=25-int(rannor(123)*3);
 if KUNDENALTER<18 then KUNDENALTER=18+int(ranuni(235)*3);
 if KUNDENALTER>85 then KUNDENALTER=85-int(ranuni(222)*3);

 if ranuni(333)>0.3 then GESCHLECHT="Männlich"; else GESCHLECHT="Weiblich";

 LENGTH FAMILIENSTAND $30.;
      if ranuni(5555)<0.25 then FAMILIENSTAND='Ledig, Alleinstehend';
 else if ranuni(5555)<0.72 then FAMILIENSTAND='Verheiratet';
 else if ranuni(5555)<0.73 then FAMILIENSTAND='Geschieden';
 else 							FAMILIENSTAND='Verwitwet';

 if 30<KUNDENALTER<40 and FAMILIENSTAND='Verwitwet' then FAMILIENSTAND='Verheiratet';
 if KUNDENALTER<30 and FAMILIENSTAND in ('Verwitwet', 'Geschieden') then FAMILIENSTAND='Ledig, Alleinstehend';
 if KUNDENALTER<20 and FAMILIENSTAND='Verheiratet' then FAMILIENSTAND='Ledig, Alleinstehend';
 
 if ranuni(4)>0.8 then ANZ_KINDER=0;
 else ANZ_KINDER=ranpoi(3123,1);
 if KUNDENALTER<25 or KUNDENALTER>60 or (FAMILIENSTAND='Ledig, Alleinstehend' and ranuni(3333)>0.3) then ANZ_KINDER=0;
 if ANZ_KINDER>4 then ANZ_KINDER=ranpoi(22222,1);
 if ANZ_KINDER=1 and ranuni(4444)>0.8 then ANZ_KINDER=2;

 LENGTH WOHNSITUATION $30.;
 if ranuni(6)<0.7 and KUNDENALTER>35 then WOHNSITUATION="Eigentum";
 else                  WOHNSITUATION="Miete";
 if ARBEITSVERH_CODE in (4,5) and KUNDENALTER<23 and FAMILIENSTAND='Ledig, Alleinstehend' then WOHNSITUATION="Wohnhaft Bei Eltern";

if ranuni(234)<0.6 and (KUNDENALTER<22 or KUNDENALTER>75) then KFZ_EIGENTUM='Nein'; 
else if ranuni(234)<0.9 then KFZ_EIGENTUM='Ja';
else KFZ_EIGENTUM='Nein';


x=ranuni(111111);
      if x<0.85  then NATIONALITAET='DE';
 else if x<0.87  then NATIONALITAET='TR';
 else if x<0.89  then NATIONALITAET='PL';
 else if x<0.90  then NATIONALITAET='IT';
 else if x<0.915 then NATIONALITAET='RO';
 else if x<0.917 then NATIONALITAET='GR';
 else if x<0.918 then NATIONALITAET='HR';
 else if x<0.919 then NATIONALITAET='RS';
 else if x<0.920 then NATIONALITAET='RU';
 else if x<0.921 then NATIONALITAET='ES';
 else if x<0.922 then NATIONALITAET='PT';
 else if x<0.923 then NATIONALITAET='CH';
 else if x<0.924 then NATIONALITAET='AT';
 else if x<0.925 then NATIONALITAET='BG';
 else if x<0.926 then NATIONALITAET='NL';
 else if x<0.927 then NATIONALITAET='FR';
 else if x<0.928 then NATIONALITAET='BE';
 else if x<0.929 then NATIONALITAET='BA';
 else if x<0.930 then NATIONALITAET='UA';
 else if x<0.931 then NATIONALITAET='HU';
 else if x<0.932 then NATIONALITAET='US';
 else if x<0.933 then NATIONALITAET='UK';
 else if x<0.934 then NATIONALITAET='SY';
 else if x<0.935 then NATIONALITAET='CN';
 else if x<0.936 then NATIONALITAET='IQ';
 else if x<0.937 then NATIONALITAET='IR';
 else if x<0.938 then NATIONALITAET='AL';
 else if x<0.939 then NATIONALITAET='VN';
 else if x<0.940 then NATIONALITAET='TH';
 else if x<0.941 then NATIONALITAET='DK';
 else if x<0.942 then NATIONALITAET='SE';
 else if x<0.943 then NATIONALITAET='CZ';
 else if x<0.944 then NATIONALITAET='MK';
 else if x<0.945 then NATIONALITAET='SK';

 else                 NATIONALITAET='XX';



 drop x;



 ARBEITSVERH_JAHRE=abs(int(rannor(2222)*2))+ranpoi(22223,7)+1;
 if KUNDENALTER>65 and ARBEITSVERH_CODE ne 1 then ARBEITSVERH_JAHRE = 1+(KUNDENALTER-65);

 if ARBEITSVERH_CODE in (4,5) and ARBEITSVERH_JAHRE>5 then ARBEITSVERH_JAHRE= 1+int(ranuni(3333*5));

 WOHNSITUATION_JAHRE=abs(int(rannor(1111)*2))+abs(int(rannor(12345)*8))+1;
 if WOHNSITUATION_JAHRE>KUNDENALTER then WOHNSITUATION_JAHRE=KUNDENALTER;

 if KUNDENALTER<23 then WOHNSITUATION_JAHRE = min(WOHNSITUATION_JAHRE,KUNDENALTER-18);
 
 if ranuni(43243)>0.8 then ANZAHL_KREDITE=0;
 else ANZAHL_KREDITE=ranpoi(12421,1);

 LENGTH ARBEITSVERH_BEFRISTET $4.; 
 if ARBEITSVERH_CODE=2 and ranuni(1234)>0.8 then ARBEITSVERH_BEFRISTET="Ja"; else ARBEITSVERH_BEFRISTET="Nein";

 LENGTH MINIJOB $4.; 
 if ARBEITSVERH_CODE=2 and ranuni(1333)>0.8 and FAMILIENSTAND="Ledig, Alleinstehend" and GESCHLECHT="Weiblich" then MINIJOB="Ja"; else MINIJOB="Nein";
 if ARBEITSVERH_CODE=2 and ranuni(672)>0.7 and FAMILIENSTAND="Ledig, Alleinstehend" and GESCHLECHT="Männlich" then MINIJOB="Ja"; else MINIJOB="Nein";



run;

proc sort data=basis2 out=basis3;
by KUNDEN_ID;
run;

proc sql noprint; select max(KUNDENALTER) into: maxage from basis3;
proc sql noprint; select min(KUNDENALTER) into: minage from basis3;
proc sql noprint; select max(ARBEITSVERH_JAHRE) into: maxjob from basis3;
proc sql noprint; select min(ARBEITSVERH_JAHRE) into: minjob from basis3;

data basis4;
 set basis3;
 GRANDMEAN=5000;

    if BRANCHE_CODE= 1 then x1=1.4;
    if BRANCHE_CODE= 2 then x1=0.8; 
	if BRANCHE_CODE= 3 then x1=0.9;
	if BRANCHE_CODE= 4 then x1=0.7;
	if BRANCHE_CODE= 5 then x1=1.5;
	if BRANCHE_CODE= 6 then x1=1.1;
	if BRANCHE_CODE= 7 then x1=0.8;
	if BRANCHE_CODE= 8 then x1=0.9;
	if BRANCHE_CODE= 9 then x1=1.1;
	if BRANCHE_CODE=10 then x1=1.1;
	if BRANCHE_CODE=11 then x1=0.7;
	if BRANCHE_CODE=12 then x1=1.2;
	if BRANCHE_CODE=13 then x1=0.9;
	if BRANCHE_CODE=14 then x1=1.1;
    if BRANCHE_CODE=15 then x1=1.0;
    if BRANCHE_CODE=16 then x1=1.0;

	if ARBEITSVERH_CODE= 1 then x2=1.5;
	if ARBEITSVERH_CODE= 2 then x2=1.0;
	if ARBEITSVERH_CODE= 3 then x2=0.7;
	if ARBEITSVERH_CODE= 4 then x2=0.6;
	if ARBEITSVERH_CODE= 5 then x2=0.5;
	if ARBEITSVERH_CODE= 6 then x2=0.9;
	if ARBEITSVERH_CODE= 7 then x2=1.3;
	if ARBEITSVERH_CODE= 8 then x2=1.0;


    x3=0.5+(KUNDENALTER-&minage)/(&maxage-&minage); format x3 8.2;


	x4=(ARBEITSVERH_JAHRE-&minjob)/(&maxjob-&minjob); format x4 8.3;
	x5=sqrt(x4);

	x6=0.75+x5;

	if GESCHLECHT='Männlich' then x6a=1; else x6a=0.8;


	NETTOEINKOMMEN=round((GRANDMEAN*x1*x2*x3*x6*x6a)+(abs(rannor(1234)*500)),100);
	if ranuni(8)<0.2 then SONSTIGE_EINNAHMEN=round(abs(rannor(1238)*300),50); else SONSTIGE_EINNAHMEN=0;

	WOHN_AUFWAND=round(NETTOEINKOMMEN*(0.3+(abs(rannor(1234)/5))),50);

	x7=NETTOEINKOMMEN+SONSTIGE_EINNAHMEN-WOHN_AUFWAND;

	if ranuni(9)<0.2 then SONSTIGE_LFD_ZAHLUNGEN=round(x7*(ranuni(34234)/2),50);else SONSTIGE_LFD_ZAHLUNGEN=0;
	if FAMILIENSTAND='Geschieden' and ANZ_KINDER>0 and GESCHLECHT='Männlich' then SONSTIGE_LFD_ZAHLUNGEN=round(x7*(ranuni(34234)/2),50)+100;



	KREDITSUMME=(ranpoi(1231,4)+5)*1000;
	if ranuni(3333)>0.5 then KREDITSUMME=KREDITSUMME+500;

	LAUFZEIT=round(abs(rannor(333333)*60),12);
	if LAUFZEIT=0 then LAUFZEIT=6;
	if ranuni(4444)>0.7 then LAUFZEIT=LAUFZEIT+6;

    
	DATUM=today()-int(ranuni(2345)*500); format DATUM date9.;
	if ranuni(4444)<0.1 then TAGESZEIT='00:00 -07:00';
    else if ranuni(4444)<0.3 then TAGESZEIT='07:00-10:00';
    else if ranuni(4444)<0.6 then TAGESZEIT='10:00-18:00';
    else if ranuni(4444)<0.9 then TAGESZEIT='18:00-22:00';
    else TAGESZEIT='22:00-24:00';



	tilgrate=KREDITSUMME/LAUFZEIT;
    unter = NETTOEINKOMMEN-(WOHN_AUFWAND+SONSTIGE_LFD_ZAHLUNGEN+tilgrate+500);

    if unter<0 then FLAG=1; else FLAG=0;

	if NATIONALITAET in ("BA","IQ","IR","RO","BG","SY") 
	and Kundenalter<25 and Familienstand="Ledig, Alleinstehend" and Geschlecht="Männlich" and tilgrate>3000 and ranuni(231)>0.95 then FLAG=1;

	if ranuni(0000)>0.99 and FLAG=0 then FLAG=1;
    if ranuni(0000)<0.2 and FLAG=1 then FLAG=0;


	ZAHLUNGSVERZUG=FLAG;
	
 


   
	drop unter tilgrate flag x1 x2 x3 x4 x5 x6 x6a x6a REGION_ID ARBEITSVERH_CODE BRANCHE_CODE GRANDMEAN;

	label
	KUNDEN_ID = "Kunden-Pseudo_ID"
    BRANCHE_DESC = "Branche"
    ARBEITSVERH_DESC = "Arbeitsverhältnis"
	PLZ = "Postleitzahl"
	ORT = "Stadt, Gemeinde"
	LAENGENGRAD = "Längengrad"
	BREITENGRAD = "Breitengrad"
	BUNDESLAND = "Bundesland"
	KUNDENALTER = "Kundenalter"
	GESCHLECHT = "Geschlecht"
	FAMILIENSTAND = "Familienstand"
	ANZ_KINDER = "Anzahl unterhaltspflichtiger Kinder"
	WOHNSITUATION = "Wohnungssituation"
	KFZ_EIGENTUM = "KFZ-Eigentum"
	NATIONALITAET = "Staatsangehörigkeit"
	ARBEITSVERH_JAHRE = "Derzeitiges Arbeitsverhältnis seit wievielen Jahren"
	WOHNSITUATION_JAHRE = "Derzeitige Wohnsituation seit wievielen Jahren"
	ANZAHL_KREDITE = "Anzahl laufender Kredite"
	ARBEITSVERH_BEFRISTET = "Befristetes Arbeitsverhältnis"
	MINIJOB = "Minijob-Status"
	NETTOEINKOMMEN = "Nettoeinkommen (monatlich)"
	SONSTIGE_EINNAHMEN = "Sonstige monatliche Einnahmen"
	WOHN_AUFWAND = "Monatlicher Aufwand für Wohnung"
	SONSTIGE_LFD_ZAHLUNGEN = "Sonstige monatliche Zahlungsverpflichtungen"
	KREDITSUMME = "Beantragte Kreditsumme"
	LAUFZEIT = "Kreditlaufzeit"
	DATUM="Antragsdatum"
	TAGESZEIT="Tageszeit"
	ZAHLUNGSVERZUG="Zahlungsverzug"
;

run;

proc sql; create table basis5 as select
a.*,
b.EVENT_ALLE label "Kalender-Event",
b.WOCHENTAG label "Wochentag"
from basis4 as a left join calendar_final as b on a.DATUM=b.KALENDERDATUM
order by a.KUNDEN_ID;
quit;



/* Verstecke Fraud */

data mydata.KREDITANTRAEGE;
set basis5;
ratio=KREDITSUMME/NETTOEINKOMMEN;

   if NATIONALITAET in ("BA", "RO", "SY", "IR","XX","BG", "AL", "IQ") then x1=0.8+rannor(1234)/5; else x1=0.3+ranuni(1234)/3;
   if KUNDENALTER<35                                            then x2=0.8+rannor(9999)/5; else x2=0.3+ranuni(9999)/3;
   if KREDITSUMME>10000                                         then x3=0.8+rannor(3211)/5; else x3=ranuni(3211)/3;
   if LAUFZEIT>96                                               then x4=0.8+rannor(8888)/5; else x4=ranuni(8888)/3;
   if ratio>10                                     				then x5=0.8+rannor(7899)/5; else x5=ranuni(7899)/3;
   if Arbeitsverh_DESC in ("Selbständig, Freiberuflich", "Studium") then x6=0.8+rannor(5444)/5; else x6=ranuni(4444)/3;
   if tageszeit =("00:00-07:00")                                 then x7=0.8+rannor(5444)/5; else x7=ranuni(4444)/3;

final=x1*x2*x3*x4*x5*x6*x7;

format final 8.4;
if final>0.02 then BETRUGSKENNZEICHEN='Betrugsverdacht'; else BETRUGSKENNZEICHEN='Kein Verdacht';
label BETRUGSKENNZEICHEN = "Betrugsverdacht-Kennzeichen";

x0=ranuni(2222);
if x0<0.01 then NETTOEINKOMMEN=round(NETTOEINKOMMEN*(1+abs(rannor(3333)/3)),100);




drop ratio x0 x1 x2 x3 x4 x5 x6 x7 final;



run;

proc sort data=mydata.KREDITANTRAEGE;
 by DATUM;
run;

data mydata.KREDITANTRAEGE_TRAIN;
 set mydata.KREDITANTRAEGE;
 obs=_n_;
 if obs>100000 then delete;
 format KUNDEN_ID z7.0;
 drop obs;
run;


data mydata.KREDITANTRAEGE_SCORE;
 set mydata.KREDITANTRAEGE;
 obs=_n_;
 if obs<=100000 then delete;
 format KUNDEN_ID z7.0;
 drop obs;
run;