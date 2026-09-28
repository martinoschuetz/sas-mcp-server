*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
*
*  Stored Process registriert durch
*  Enterprise Guide Stored Process Manager V6.1
*
*  ====================================================================
*  Stored Process-Name: Stored Process für Simulator
*  ====================================================================
*
*  Wörterbuch von Stored Process-Eingabeaufforderungen:
*  ____________________________________
*  PDRUCKGESCHWINDIGKEIT
*       Typ: Numerisch
*      Etikett: pDruckgeschwindigkeit
*       Attr: Sichtbar
*    Standard: 2050
*  ____________________________________
*  PPRESSTYP
*       Typ: Text
*      Etikett: Presstyp-Bezeichnung
*       Attr: Sichtbar
*    Standard: Motter94
*  ____________________________________
*  PTINTE
*       Typ: Numerisch
*      Etikett: Tinte in %
*       Attr: Sichtbar
*    Standard: 75
*  ____________________________________
*;


*ProcessBody;

%global PDRUCKGESCHWINDIGKEIT
        PPRESSTYP
        PTINTE;

%STPBEGIN;

OPTIONS VALIDVARNAME=ANY;

%macro ExtendValidMemName;

%if %sysevalf(&sysver>=9.3) %then options validmemname=extend;

%mend ExtendValidMemName;

%ExtendValidMemName;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);

/* Begin Librefs -- do not edit this line */
Libname QCD BASE 'C:\Daten\THYKRP\Data\Erzeugung_Logs';
/* End Librefs -- do not edit this line */

LIBNAME QCD BASE "C:\Daten\THYKRP\Data\Erzeugung_Logs" ;

data qcd.ToSCore;
 set qcd.printer_mart;
 where DRUCKAUFTRAG_NUMMER=38064 and Tintentyp_bezeichnung='uncoated';
 drop banding_flag;
 

run;

%global pDruckgeschwindigkeit;
%global pPresstyp;
%global pTinte;
/*
%let pDruckgeschwindigkeit=2050;
%let ppresstyp=super;
%let pTinte=75;
*/

data qcd.Gescored;
  set qcd.ToScore;
 Tinte_prozent=&ptinte;
 Papiertyp_Bezeichnung="&pPresstyp";
 Druckgeschwindigkeit=&pDruckgeschwindigkeit;

 %include "C:\DATEN\THYKRP\Scorecode.sas";
 label EM_EVENTPROBABILITY='Wahrscheinlichkeit für Banding';
run;



proc print data=qcd.gescored noobs label;
title "Simulationsergebnis";
var 
Druckgeschwindigkeit
Presstyp_Bezeichnung
Tinte_Prozent
EM_EVENTPROBABILITY;
format eM_EVENTPROBABILITY percent8.2;
run;

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
;*';*";*/;quit;
%STPEND;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);

