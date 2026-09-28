/* Geocodierung von Postleitzahlen für Deutschland */

/* Hole Geocodes über http://fa-technik.adfc.de/code/opengeodb */

libname a clear;
libname a "C:\Sonstiges\SASCODE";


 
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
    INFILE 'C:\Sonstiges\SASCODE\GEODATEN.TXT'
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

