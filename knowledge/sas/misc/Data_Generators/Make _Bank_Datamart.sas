%let geopath=C:\Sonstiges\SASCODE\GEODATEN.TXT;
%let datapath=C:\Sonstiges\SASCODE\Bank_Rohdaten.csv;
libname a clear;
libname a "C:\Daten\quellen";
%let nreply=200;


DATA tmp0;
LENGTH
CUST_AGE           8
CUST_GENDER      $ 8
CUST_HHSIZE        8
DEPENDENTS         8
YEARS_RESIDENCE    8
NATIONALITY      $ 11
MARITAL_STATUS   $ 11
PROFESSIONAL_STATUS $ 32
AQUISITION_CHANNEL $ 14
CUST_DURATION      8
CHK_ACCT_STATUS    8
CHK_ACCT_AVG_BALANCE   8
CHK_ACCT_AVG_BAL_M1   8
CHK_ACCT_AVG_BAL_M2   8
CHK_ACCT_AVG_BAL_M3   8
CHK_ACCT_AVG_BAL_M4   8
CHK_ACCT_AVG_BAL_M5   8
CHK_ACCT_AVG_BAL_M6   8
TRAD_ACCT_STATUS   8
TRAD_ACCT_AVG_BAL_M1_3   8
TRAD_ACCT_AVG_BAL_M4_6   8
CARD_STATUS        8
CARD_TYPE        $ 14
CARD_ACCT_AVG_BAL_M1_3   8
CARD_ACCT_AVG_BAL_M4_6   8
SAVINGSPLAN_STATUS   8
SAVINGSPLAN_DEBIT   8
CREDITSCORE        8
DEMANDNOTES_12M    8
RESPONSE_HIST_12M   8
TREATMENT_GROUP    8
ACTIVATION_DT      8
DEACTIVATION_DT    8
CANCEL_EVENT       8
REASONCODE       $ 17
CUSTOMER_ID        8
RISKBAND           8
PLZ                8
ORT              $ 27
LONGITUDE          8
LATITUDE           8
PLZ_REGION         8
CHURN              8 ;
FORMAT
CUST_AGE         BEST2.
CUST_GENDER      $CHAR8.
CUST_HHSIZE      BEST1.
DEPENDENTS       BEST1.
YEARS_RESIDENCE  BEST1.
NATIONALITY      $CHAR11.
MARITAL_STATUS   $CHAR11.
PROFESSIONAL_STATUS $CHAR32.
AQUISITION_CHANNEL $CHAR14.
CUST_DURATION    BEST2.
CHK_ACCT_STATUS  BEST1.
CHK_ACCT_AVG_BALANCE BEST7.
CHK_ACCT_AVG_BAL_M1 BEST7.
CHK_ACCT_AVG_BAL_M2 BEST8.
CHK_ACCT_AVG_BAL_M3 BEST7.
CHK_ACCT_AVG_BAL_M4 BEST7.
CHK_ACCT_AVG_BAL_M5 BEST7.
CHK_ACCT_AVG_BAL_M6 BEST8.
TRAD_ACCT_STATUS BEST1.
TRAD_ACCT_AVG_BAL_M1_3 BEST8.
TRAD_ACCT_AVG_BAL_M4_6 BEST8.
CARD_STATUS      BEST1.
CARD_TYPE        $CHAR14.
CARD_ACCT_AVG_BAL_M1_3 BEST8.
CARD_ACCT_AVG_BAL_M4_6 BEST8.
SAVINGSPLAN_STATUS BEST1.
SAVINGSPLAN_DEBIT BEST4.
CREDITSCORE      BEST8.
DEMANDNOTES_12M  BEST1.
RESPONSE_HIST_12M BEST1.
TREATMENT_GROUP  BEST1.
ACTIVATION_DT    DATE9.
DEACTIVATION_DT  DATE9.
CANCEL_EVENT     BEST1.
REASONCODE       $CHAR17.
CUSTOMER_ID      BEST10.
RISKBAND         BEST2.
PLZ              BEST5.
ORT              $CHAR27.
LONGITUDE        BEST16.
LATITUDE         BEST16.
PLZ_REGION       BEST2.
CHURN            BEST1. ;
INFORMAT
CUST_AGE         BEST2.
CUST_GENDER      $CHAR8.
CUST_HHSIZE      BEST1.
DEPENDENTS       BEST1.
YEARS_RESIDENCE  BEST1.
NATIONALITY      $CHAR11.
MARITAL_STATUS   $CHAR11.
PROFESSIONAL_STATUS $CHAR32.
AQUISITION_CHANNEL $CHAR14.
CUST_DURATION    BEST2.
CHK_ACCT_STATUS  BEST1.
CHK_ACCT_AVG_BALANCE BEST7.
CHK_ACCT_AVG_BAL_M1 BEST7.
CHK_ACCT_AVG_BAL_M2 BEST8.
CHK_ACCT_AVG_BAL_M3 BEST7.
CHK_ACCT_AVG_BAL_M4 BEST7.
CHK_ACCT_AVG_BAL_M5 BEST7.
CHK_ACCT_AVG_BAL_M6 BEST8.
TRAD_ACCT_STATUS BEST1.
TRAD_ACCT_AVG_BAL_M1_3 BEST8.
TRAD_ACCT_AVG_BAL_M4_6 BEST8.
CARD_STATUS      BEST1.
CARD_TYPE        $CHAR14.
CARD_ACCT_AVG_BAL_M1_3 BEST8.
CARD_ACCT_AVG_BAL_M4_6 BEST8.
SAVINGSPLAN_STATUS BEST1.
SAVINGSPLAN_DEBIT BEST4.
CREDITSCORE      BEST8.
DEMANDNOTES_12M  BEST1.
RESPONSE_HIST_12M BEST1.
TREATMENT_GROUP  BEST1.
ACTIVATION_DT    DATE9.
DEACTIVATION_DT  DATE9.
CANCEL_EVENT     BEST1.
REASONCODE       $CHAR17.
CUSTOMER_ID      BEST10.
RISKBAND         BEST2.
PLZ              BEST5.
ORT              $CHAR27.
LONGITUDE        BEST16.
LATITUDE         BEST16.
PLZ_REGION       BEST2.
CHURN            BEST1. ;
INFILE "&datapath"
LRECL=32767
FIRSTOBS=2
ENCODING="WLATIN1"
DLM='3b'x
MISSOVER
DSD ;
INPUT
CUST_AGE         : ?? BEST2.
CUST_GENDER      : $CHAR8.
CUST_HHSIZE      : ?? BEST1.
DEPENDENTS       : ?? BEST1.
YEARS_RESIDENCE  : ?? BEST1.
NATIONALITY      : $CHAR11.
MARITAL_STATUS   : $CHAR11.
PROFESSIONAL_STATUS : $CHAR32.
AQUISITION_CHANNEL : $CHAR14.
CUST_DURATION    : ?? BEST2.
CHK_ACCT_STATUS  : ?? BEST1.
CHK_ACCT_AVG_BALANCE : ?? COMMA7.
CHK_ACCT_AVG_BAL_M1 : ?? COMMA7.
CHK_ACCT_AVG_BAL_M2 : ?? COMMA8.
CHK_ACCT_AVG_BAL_M3 : ?? COMMA7.
CHK_ACCT_AVG_BAL_M4 : ?? COMMA7.
CHK_ACCT_AVG_BAL_M5 : ?? COMMA7.
CHK_ACCT_AVG_BAL_M6 : ?? COMMA8.
TRAD_ACCT_STATUS : ?? BEST1.
TRAD_ACCT_AVG_BAL_M1_3 : ?? COMMA8.
TRAD_ACCT_AVG_BAL_M4_6 : ?? COMMA8.
CARD_STATUS      : ?? BEST1.
CARD_TYPE        : $CHAR14.
CARD_ACCT_AVG_BAL_M1_3 : ?? COMMA8.
CARD_ACCT_AVG_BAL_M4_6 : ?? COMMA8.
SAVINGSPLAN_STATUS : ?? BEST1.
SAVINGSPLAN_DEBIT : ?? BEST4.
CREDITSCORE      : ?? COMMA8.
DEMANDNOTES_12M  : ?? BEST1.
RESPONSE_HIST_12M : ?? BEST1.
TREATMENT_GROUP  : ?? BEST1.
ACTIVATION_DT    : ?? DATE9.
DEACTIVATION_DT  : ?? DATE9.
CANCEL_EVENT     : ?? BEST1.
REASONCODE       : $CHAR17.
CUSTOMER_ID      : ?? BEST10.
RISKBAND         : ?? BEST2.
PLZ              : ?? BEST5.
ORT              : $CHAR27.
LONGITUDE        : ?? COMMA16.
LATITUDE         : ?? COMMA16.
PLZ_REGION       : ?? BEST2.
CHURN            : ?? BEST1. ;
RUN;





%Macro replicate;
%do i=1 %to &nreply;
data tmp&i;
 set tmp0;
 copy=&i;
run;
%end;

data final;
 set tmp1 - tmp&nreply;
run;

proc datasets noprint nodetails library=work; 
 delete tmp1 - tmp&nreply /memtype=data; 
run;

%mend;



%replicate;


data final2;
 set final (drop=CUSTOMER_ID);
 if ranuni(1234)>0.9 then delete;
 xxx=_n_*1000+int(ranuni(1234)*999);
 format xxx z10.0;
 CUSTOMER_ID=vvalue(xxx);
 label Customer_ID ="Kunden-ID";
 drop xxx;
run;

proc sql; create table x as select distinct customer_id
from final2;
quit;




 
DATA x1(label='TEST');
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
    INFILE "&Geopath"
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


data GEODATEN(label='');
 set x1;
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
run;




data region;
 set geodaten;
 xid=_n_;
 if ort in ("München", 
            "Stuttgart",
			"Karlsruhe",
           "Hamburg", 
           "Berlin", 
           "Düsseldorf", 
           "Essen", 
           "Köln", 
           "Dortmund", 
           "Duisburg", 
           "Münster", 
           "Wuppertal", 
           "Bonn", 
           "Bielefeld",
           "Hagen",
           "Remscheid",
           "Gelsenkirchen",
           "Bochum")
    then flag=1;
	else flag=0;
    if ranuni(1200)>0.990 or (flag=1 and ranuni(12000)>0.85);
run;

data region2;
 set region;
 
 region_id=_n_;
 drop xid;
run;



proc sql noprint; select max(Region_id) into :regions from region2;quit;
%put anzahl=&regions;

data final3;
 set final2;
 region_id=int(ranuni(123)*&regions)+1;

 
label RISKBAND = "Risikoband";
     if creditscore<-800 then RISKBAND='01';
else if creditscore<-500 then RISKBAND='02';
else if creditscore< 200 then RISKBAND='03';
else if creditscore< 600 then RISKBAND='04';
else                          RISKBAND='05';

 if riskband in ('01','02') then frisk=1;
 else if riskband in ('03') then frisk=0.9;
 else if riskband in ('04') then frisk=0.86;
 else                            frisk=0.75;
 


 f0=rangam(1111,3);
 f1=rangam(1233543,4);
 f2=rangam(125,5);
 f3=rangam(1333333,4);
 f4=rangam(120033,3);
 f5=rangam(12300033,5);
 f6=rangam(1230533,7);

 if cust_age>50 then fage=1.5+rannor(232)/10; else fage=1.0+rannor(234)/10;
 if cust_gender = 'Männlich' then fg=1.5+rannor(3333)/10; else fg=1+rannor(2345)/10;
 if years_residence <10 then fr=1+rannor(3335)/10; else fr=1.9+rannor(3333)/10;

 if nationality='Ausländisch' and ranuni(432456)>0.99 then fausl=6; else if nationality='Ausländisch' then fausl=0.7; else fausl=1;

 if response=1 then fresp=1.5; else fresp=1;

 fall=fage*fg*fr*fausl*fresp*frisk;

CHK_ACCT_AVG_BALANCE= CHK_ACCT_AVG_BALANCE		* f0 * fall;
CHK_ACCT_AVG_BAL_M1	= CHK_ACCT_AVG_BAL_M1	    * f1 * fall;
CHK_ACCT_AVG_BAL_M2	= CHK_ACCT_AVG_BAL_M2	    * f2 * fall;
CHK_ACCT_AVG_BAL_M3	= CHK_ACCT_AVG_BAL_M3	    * f3 * fall;	
CHK_ACCT_AVG_BAL_M4	= CHK_ACCT_AVG_BAL_M4	    * f4 * fall;	 
CHK_ACCT_AVG_BAL_M5	= CHK_ACCT_AVG_BAL_M5	    * f5 * fall;	
CHK_ACCT_AVG_BAL_M6	= CHK_ACCT_AVG_BAL_M6	    * f6 * fall ;


fa1=rangam(2,5);
fa2=rangam(4,7);

fb1=rangam(8,4);
fb2=rangam(9,4);


TRAD_ACCT_AVG_BAL_M1_3 = TRAD_ACCT_AVG_BAL_M1_3 * fa1*fall;
TRAD_ACCT_AVG_BAL_M4_6 = TRAD_ACCT_AVG_BAL_M4_6 * fa2*fall;
CARD_ACCT_AVG_BAL_M1_3 = CARD_ACCT_AVG_BAL_M1_3 * fb1*fall;
CARD_ACCT_AVG_BAL_M4_6 = CARD_ACCT_AVG_BAL_M4_6 * fb2*fall;

label CARD_ACCT_AVG_BAL_M1_3 = "Saldo Kreditkarte letzte 3 Monate";

drop f0-f6 fall fr fg fausl fa1 fa2 fb1 fb2 fresp fage frisk copy;


if ranuni(12321)>0.9995 then CHK_ACCT_AVG_BALANCE =CHK_ACCT_AVG_BALANCE * 20;




run;

proc sql; create table final4 as select 
a.*,
b.PLZ,
b.ORT,
b.Laengengrad as LONGITUDE,
b.breitengrad as LATITUDE
from final3 as a left join region2 as b on a.region_id=b.region_id
order by customer_id;
quit;

data final5;
 set final4(drop=response treatment_group);
 /* Lösche Datensätze per Zufallsauswahl */
if ranuni(333)>0.5 then delete;

 
 PLZ_REGION=substr(PLZ,1,2);
 creditscore=creditscore*(-1);
 

 py=1/(1+exp(1
       +0.35 * (1/CUST_DURATION)
       +0.26 * creditscore/20
       +0.20 * cust_age
	   +0.59 * (professional_status='Selbständig/Hochqualifiziert')
	   +0.50 * (PLZ_REGION='86')
       +rannor(222)*4));
 
 if py>0.5 then CHURN=1; else CHURN=0;




 if CHURN = 0 then do;
    CANCEL_EVENT=0;
	REASONCODE='Aktiv';
	DEACTIVATION_DT=.;
 end;

 if CHURN = 1 then do;
    if ranuni(123)>0.1 then do; 
      CANCEL_EVENT=1;	    
	  REASONCODE='Vertragskündigung';
	end;
    if ranuni(123)<=0.1 then do; 
      CANCEL_EVENT=2;	    
	  REASONCODE='Inaktivität';
	end;

  	if missing(DEACTIVATION_DT) then DEACTIVATION_DT=ACTIVATION_DT+ranpoi(123,20)*365;
	if DEACTIVATION_DT>'01JAN2014'D then DEACTIVATION_DT=DEACTIVATION_DT-365;
 end;
 label CHURN='Kündigungsstatus'
       PLZ='Postleitzahl'
	   PLZ_REGION='PLZ-Region'
	   ORT ='Ort'
	   LONGITUDE='Geo-Längengrad'
	   LATITUDE='Geo-Breitengrad';

	   drop region_id flag py ;
run;


/* Finale Tabelle generieren */ 
data a.BANK_DATAMART_V2; 
set final5;

run;

