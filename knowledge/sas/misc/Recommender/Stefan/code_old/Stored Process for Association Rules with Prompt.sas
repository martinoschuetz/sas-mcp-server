*  Begin EG generated code (do not edit this line);

* 
*  Stored process registered by 
*  Enterprise Guide Stored Process Manager V6.1 
* 
*  ==================================================================== 
*  Stored process name: Stored Process for StP_AssociationRules 
* 
*  Description: Stored Process für Warenkorb-Assoziationsanalyse 
*  ==================================================================== 
* 
*  Stored process prompt dictionary: 
*  ____________________________________ 
*  _ODSSTYLE 
*       Type: Text 
*      Label: _odsstyle 
*       Attr: Hidden 
*    Default: meadow 
*  ____________________________________ 
*  CAT 
*       Type: Text 
*      Label: Kategorie 
*       Attr: Visible, Required 
*    Default: Garten & Balkon 
*       Desc: Warenkategorie auswählen: 
*  ____________________________________ 
*  CRIT 
*       Type: Text 
*      Label: Sortierkriterium für Anzeige 
*       Attr: Visible, Required 
*    Default: conf 
*       Desc: Sortieren der Anzeige nach gewählter Kennzahl 
*  ____________________________________ 
*  ITEMS 
*       Type: Numeric 
*      Label: Anzahl Items pro Regel 
*       Attr: Visible, Required 
*    Default: 2 
*       Desc: Geben Sie die Anzahl Items pro  Regel ein (minimal 2, 
*             maximal 4) 
*  ____________________________________ 
*  MAXOBS 
*       Type: Numeric 
*      Label: Maximale Anzahl Regeln: 
*       Attr: Visible, Required 
*    Default: 50 
*       Desc: Maximale Anzahl Regeln (10-200) eingeben 
*  ____________________________________ 
*  MINCONF 
*       Type: Numeric 
*      Label: Konfidenz: 
*       Attr: Visible, Required 
*    Default: 5 
*       Desc: Mindestwert für Konfidenzwert (zwischen 2 und 99) 
*             eingeben. 
*  ____________________________________ 
*  SUPPORT 
*       Type: Numeric 
*      Label: Support: 
*       Attr: Visible, Required 
*    Default: 50 
*       Desc: Mindetsanzahl Transaktionen (Support) eingeben 
*  ____________________________________ 
*;

*ProcessBody;
%global _ODSSTYLE 
	CAT 
	CRIT 
	ITEMS 
	MAXOBS 
	MINCONF 
	SUPPORT;

%STPBEGIN;
OPTIONS VALIDVARNAME=ANY;

%macro ExtendValidMemName;
	%if %sysevalf(&sysver>=9.3) %then
		options validmemname=extend;
%mend ExtendValidMemName;

%ExtendValidMemName;

*  End EG generated code (do not edit this line);
%macro prep;
	%if &_odsdest=TAGSETS.EXCELXP %then
		%do;

			data _null_;
				rc = stpsrv_header('Content-type','application/vnd.ms-excel');
				rc = stpsrv_header('Content-disposition','attachment; filename=regeln.xlsx');
			run;

		%end;
%mend;

%prep;

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);

* 
*  Stored Process registriert durch 
*  Enterprise Guide Stored Process Manager V6.1 
* 
*  ==================================================================== 
*  Stored Process-Name: Stored Process for StP_AssociationRules 
* 
*  Beschreibung: Stored Process für Warenkorb-Assoziationsanalyse 
*  ==================================================================== 
* 
*  Wörterbuch von Stored Process-Eingabeaufforderungen: 
*  ____________________________________ 
*  CAT 
*       Typ: Text 
*      Etikett: Kategorie 
*       Attr: Sichtbar, Erforderlich 
*    Standard: Garten & Balkon 
*       Beschr.: Warenkategorie auswählen: 
*  ____________________________________ 
*  CRIT 
*       Typ: Text 
*      Etikett: Sortierkriterium für Anzeige 
*       Attr: Sichtbar, Erforderlich 
*    Standard: conf 
*       Beschr.: Sortieren der Anzeige nach gewählter Kennzahl 
*  ____________________________________ 
*  ITEMS 
*       Typ: Numerisch 
*      Etikett: Anzahl Items pro Regel 
*       Attr: Sichtbar, Erforderlich 
*    Standard: 2 
*       Beschr.: Geben Sie die Anzahl Items pro  Regel ein (minimal 2, 
*                maximal 4) 
*  ____________________________________ 
*  MAXOBS 
*       Typ: Numerisch 
*      Etikett: Maximale Anzahl Regeln: 
*       Attr: Sichtbar, Erforderlich 
*    Standard: 50 
*       Beschr.: Maximale Anzahl Regeln (10-200) eingeben 
*  ____________________________________ 
*  MINCONF 
*       Typ: Numerisch 
*      Etikett: Konfidenz: 
*       Attr: Sichtbar, Erforderlich 
*    Standard: 5 
*       Beschr.: Mindestwert für Konfidenzwert (zwischen 2 und 99) 
*                eingeben. 
*  ____________________________________ 
*  SUPPORT 
*       Typ: Numerisch 
*      Etikett: Support: 
*       Attr: Sichtbar, Erforderlich 
*    Standard: 50 
*       Beschr.: Mindetsanzahl Transaktionen (Support) eingeben 
*  ____________________________________ 
*;

*ProcessBody;
%global CAT 
	CRIT 
	ITEMS 
	MAXOBS 
	MINCONF 
	SUPPORT;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);
/* Begin Librefs -- do not edit this line */
LIBNAME D2_DATA BASE "C:\Projects\Data\VA";

/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Begin Librefs -- do not edit this line */
/* End Librefs -- do not edit this line */
/* Verweis auf das Verzeichznis der SAS Tabelle Bondaten_baumarkt */

/*%let fpath=C:\Daten\QUELLEN;
libname outlib "&fpath";*/

/* Stored Process Eingabe-Parameter */

/* Kategorie (Liste mit Text-Auswahlmöglichkeiten für die zu wählende Kategorie):
Bad & Sanitär 
Bauen & Renovieren
Farben & Tapeten
Freizeit & Haustier
Garten & Balkon
Haushalt & Wohnen
Heizen & Klima
Leuchten & Elektrobedarf
Maschinen & Werkzeuge
PKW & Fahrrad 
(Voreinstellung: Garten & Balkon) */

* %let cat=Garten & Balkon;
/* Anzahl Artikel pro Regel: Integer-Wertebereich von 2-4 (Voreinstellung 2) */
* %let items=3;
/* Untergrenze für Konfidenz: Integer-Wertebereich von 2-99 (Voreinstellung 5) */
* %let minconf=15;
/* Untergrenze für Support: Integer-Wertebereich von 10-1000 (Voreinstellung 50) */
* %let support=60;
/* Maximale Anzahl Regeln: Integer-Wertebereich von 10-200 (Voreinstellung 50) */
* %let maxobs=100;
/* Sortierungskriterium für Regelanzeige: aus Kategorien: conf (Voreinstellung), support, lift, count*/
* %let crit=conf;
/* Sample Code Assoc*/
data x;
	set D2_DATA.Bondaten_baumarkt;
	where KATEGORIE="&cat";
run;

/* Run the DMDB Procedure */
proc dmdb batch data=x
	dmdbcat=catRule;
	id trans_id;
	class artname(desc);
run;

/* Run the ASSOC Procedure */
proc assoc data=x
	dmdbcat=catRule out=assocOut
	items=&items support=&support;
	customer trans_id;
	target artname;
run;

/*Run the RULEGEN Procedure */
proc rulegen in=assocOut
	out=ruleOut minconf=&minconf;
run;

proc sql noprint;
	select max(set_size) into:set from ruleout;
quit;

/* Fitlern der Rohergebnistabelle */
data results;
	set ruleout(obs=&maxobs);
	where set_size>1;
	label 
		set_size="Anzahl\Artikel"
		rule ="Regelbeschreibung"
		count="Trans-\aktionen"
		support ="Support\in %"
		conf ="Konfidenz "
		exp_conf="Erwartete\Konfidenz"
		lift ="Lift-\Faktor ";
run;

/* Sortiere Ergebnisse nach Sortierkriterium*/
proc sort data=results out=results2;
	by descending &crit;
run;

%macro sortlabel;
	%global slabel;

	%if &crit = conf %then
		%let slabel = Konfidenz;
	%else %if &crit = count %then
		%let slabel = Anzahl Transaktionen;
	%else %if &crit = lift %then
		%let slabel = Lift;
	%else %if &crit = support %then
		%let slabel = Support %;
%mend;

%sortlabel;
%put slabel = &slabel;

data results2;
	set results2;
	format count commax16.0;
	format support lift conf exp_conf commax8.2;
	rule_id=_n_;
	label rule_id='Regel-\nummer';
run;

/* Export in CSV Datei für spätere Download-Bereitstellung */

/*
proc export data=results2 dbms=CSV file="/data/demo63/demogroup2/data/Regeln.csv" replace;
delimiter=";";
run;
*/

/* Macro fängt Situation ab, bei der keine Regel gefunden wird */
%macro mdisplay;
	title "Gefundene Assoziationsregeln für Kategorie: &cat";
	title2 "Maximale Anzahl Artikel pro Regel: &items";
	title3 "Untergrenze für Konfidenz: &minconf.% und Mindestanzahl Transaktionen pro Regel (Support): &support";
	title4 "Sortiert nach: &slabel";

	/*footnote1 justify=CENTER link="file:///data/demo63/demogroup2/data/Regeln.csv" "Als CSV Datei herunterladen";*/
	footnote1 justify=CENTER "<a target='_blank' href='&_url.?%NRBQUOTE(&)_program=&_program%NRBQUOTE(&)_odsdest=TAGSETS.EXCELXP'>Als Excel Datei herunterladen</a>";
	footnote2 justify=LEFT "Legende";
	footnote3 justify=LEFT "Support in % = Transaktionen in % von Gesamtanzahl";
	footnote4 justify=LEFT "Konfidenz = bedingte Wahrscheinlichkeit in % für rechte Regelseite";
	footnote5 justify=LEFT "Erwartete Konfidenz = Wahrscheinlichkeit in % für rechte Regelseite bei Unabhängigkeit";
	footnote6 justify=LEFT "Lift-Faktor = Quotient aus Konfidenz zu erwarteter Konfidenz";

	%if %eval(&set)=1 %then
		%do;
			footnote1;
			footnote2;
			footnote3;
			footnote4;
			footnote5;
			footnote6;

			data x;
				length x $190.;

				if _n_=1 then
					x="Keine geeignete Regel für diese Konstellation gefunden. Bitte variieren Sie die Eingabe.";
				label x='Achtung';
			run;

			proc print data=x noobs label;
			run;

		%end;
	%else
		%do;

			proc print data=results2 noobs label split='\' style(data)=[font_size=12pt] style(header)=[font_size=12pt];
				var rule_id set_size count rule support conf exp_conf lift;
			run;

			title;
			title2;
			title3;
			title4;
			footnote1;
			footnote2;
			footnote3;
			footnote4;
			footnote5;
			footnote6;
		%end;
%mend;

%mdisplay;

/* Ende des Stored Process (man könnte die Liste der generierten Regeln noch als Download für Excel anbieten,
 müsste dann den Code noch mal anpassen )*/

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
;
*';
*";
*/;
quit;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);
*  Begin EG generated code (do not edit this line);
;
*';
*";
*/;
quit;

%STPEND;

*  End EG generated code (do not edit this line);