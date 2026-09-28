libname a "D:\DATEN\QUELLEN";

data tmp;
 set a.insurance_vdd;
run;

proc sql; create table artikel as select distinct tariftyp from tmp;
proc sql; create table artikelgruppe as select distinct sparte from tmp;
proc sql; create table warengruppe as select distinct bezirksdirektion from tmp;
quit;

data artikel;
 set artikel;
 Artikelnr=_N_;
run;

data warengruppe;
 set warengruppe;
 warengruppe=_n_;
run;


proc sql; create table tmp2 as select a.artikelnr, a.tariftyp,b.warengruppe, b.bezirksdirektion
from artikel as a, warengruppe as b;
quit;

proc sql; create table tmp3 as select a.*,b.artikelnr,c.warengruppe
from tmp as a, artikel as b, warengruppe as c where 
(a.bezirksdirektion=c.bezirksdirektion and a.tariftyp=b.tariftyp);
quit;

data tmp3;
 set tmp3;
 length Abteilung $40.;

 if trim(sparte)='Haftpflicht' then Abteilung='Medien, Tonträger'; 
 else if trim(sparte)='Hausrat/Gebäude' then abteilung='Haushaltswaren';
 else if trim(sparte)='Kraftfahrzeug' then abteilung='Textil';

 if trim(sparte)='Haftpflicht' then abtnr=1; 
 else if trim(sparte)='Hausrat/Gebäude' then abtnr=2;
 else if trim(sparte)='Kraftfahrzeug' then abtnr=3;

 AG=100000*abtnr+1000*warengruppe+10*artikelnr;

 Artikelgruppencode=put(ag,z7.);
 Warengruppencode='WG'||trim(put(warengruppe,z2.));
 
 if zielbinaer='Über Plan' then Status='Unter Plan'; else if zielbinaer='Unter Plan' then Status='Über Plan';
 
 Zielerreichungsgrad=zielerreichung;
 Vertriebsregion=region;
 Umsatz=gesamtvolumen/100;
 Bestellungen=int(schadenaufw)/200;
 Retourenquote=neuvertraege/gesamtvolumen;
 Rohertrag=deckungsbeitrag1;
 Deckungsbeitrag=deckungsbeitrag2;
 GK_Abteilung=kosten_sparte;
 GK_Warengruppe=kosten_tariftyp;


 drop artikelnr sparte tariftyp bezirksdirektion ag warengruppe abtnr zielbinaer zielerreichung
      gesamtvolumen schadenaufw neuvertraege deckungsbeitrag1 deckungsbeitrag2 kosten_sparte kosten_tariftyp region;
 run;

 proc sql; create table a.MAILORDER_VDD as select
 Zeitstempel as Monat label "Monat",
 Vertriebsregion label "Vertriebsregion",
 Abteilung label "Abteilung",
 Warengruppencode as Warengruppe label "Warengruppe",
 Artikelgruppencode as Artikelgruppe label "Artikelgruppe",
 Umsatz label "Umsatz" format 12.2,
 Bestellungen label "Anzahl Bestellungen" format 8.0,
 Retourenquote label "Retourenquote" format 8.3,
 Rohertrag label "Rohertrag" format 12.2,
 Deckungsbeitrag label "Deckungsbeitrag" format 12.2,
 GK_Abteilung label "Gemeinkosten Abteilung" format 12.2,
 GK_Warengruppe label "Gemeinkosten Warengruppe" format 12.2,
 (1/zielerreichungsgrad)*Umsatz as Planumsatz label "Planumsatz" format 12.0,
 Zielerreichungsgrad*100 as Zielerreichungsgrad label "Zielerreichung in %" format 8.2,
 Status label "Status Zielerreichung"
 from tmp3
 order by vertriebsregion, abteilung, warengruppe, artikelgruppe, zeitstempel;
quit;



