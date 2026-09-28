%global WEBOUT
				CAT 
        CRIT 
        ITEMS 
        MAXOBS 
        MINCONF 
        SUPPORT
        _ODSDEST
        _ODSOPTIONS;
 
%macro prep;
	%let WEBOUT=_webout;
	%if &_odsdest=tagsets.csv %then %do;
		data _null_;
		  rc = stpsrv_header("Content-type",        "application/vnd.ms-excel; encoding=utf-8");
			rc = stpsrv_header('Content-disposition', 'attachment; filename=regeln.csv');
		run;
		%let _ODSOPTIONS = options(Delimiter=';');
		filename outnull "/dev/null";
		%let WEBOUT=outnull;
	%end;
	%if &ITEMS= %then %let ITEMS=3;
	%if &SUPPORT= %then %let SUPPORT=60;
	%if &MAXOBS= %then %let MAXOBS=100;
	%if &MINCONF= %then %let MINCONF=15;
	%if &CRIT= %then %let CRIT=conf;
  %put &ITEMS. &SUPPORT. &MAXOBS. &MINCONF. &CRIT.;
  
  %let CAT=%sysfunc(tranwrd(&CAT.,_^_, %STR( )&%STR( )));
  %put &CAT.;
%mend;
%prep;

/* Begin Librefs -- do not edit this line */
LIBNAME D2_DATA BASE "C:\Projects\Data\VA";
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
proc sql noprint; select max(set_size) into:set from ruleout;quit;



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
%if &crit = conf %then %let slabel = Konfidenz;
%else %if &crit = count %then %let slabel = Anzahl Transaktionen;
%else %if &crit = lift %then %let slabel = Lift;
%else %if &crit = support %then %let slabel = Support %;
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

/* Macro fängt Situation ab, bei der keine Regel gefunden wird */
%macro mdisplay;

title "Gefundene Assoziationsregeln für Kategorie: &cat";
title2 "Maximale Anzahl Artikel pro Regel: &items";
title3 "Untergrenze für Konfidenz: &minconf.% und Mindestanzahl Transaktionen pro Regel (Support): &support";
title4 "Sortiert nach: &slabel";

%let NEWCAT=%sysfunc(tranwrd(&CAT.,&,^));
%let NEWCAT=%sysfunc(tranwrd(&NEWCAT.,%STR( ),_));

%let excelurl=&_url.?%NRBQUOTE(&)_program=&_program%NRBQUOTE(&)_odsdest=tagsets.csv;
%let excelurl=&excelurl.%NRBQUOTE(&)ITEMS=&ITEMS.;
%let excelurl=&excelurl.%NRBQUOTE(&)MINCONF=&MINCONF.;
%let excelurl=&excelurl.%NRBQUOTE(&)SUPPORT=&SUPPORT.;
%let excelurl=&excelurl.%NRBQUOTE(&)MAXOBS=&MAXOBS.;
%let excelurl=&excelurl.%NRBQUOTE(&)CAT=&NEWCAT.;
%let excelurl=&excelurl.%NRBQUOTE(&)CRIT=&CRIT.;

footnote1 justify=CENTER "<a target='_blank' href='&excelurl.'>Als CSV Datei herunterladen</a>";
footnote2 justify=LEFT "Legende";
footnote3 justify=LEFT "Support in % = Transaktionen in % von Gesamtanzahl";
footnote4 justify=LEFT "Konfidenz = bedingte Wahrscheinlichkeit in % für rechte Regelseite";
footnote5 justify=LEFT "Erwartete Konfidenz = Wahrscheinlichkeit in % für rechte Regelseite bei Unabhängigkeit";
footnote6 justify=LEFT "Lift-Faktor = Quotient aus Konfidenz zu erwarteter Konfidenz";

%if %eval(&set)=1 %then %do;
  footnote1;
  footnote2;
  footnote3;
  footnote4;
  footnote5;
  footnote6;

  data x;
   length x $190.;
    if _n_=1 then x="Keine geeignete Regel für diese Konstellation gefunden. Bitte variieren Sie die Eingabe.";

	label x='Achtung';
   run;
   proc print data=x noobs label;
   run;
%end;
%else %do;

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

data _null_;
	file &WEBOUT.;
	length long $1024;
	input;
	long = _infile_;
	long = tranwrd(long, '$ITEMS$',  trim(left("&ITEMS.")));
	long = tranwrd(long, '$MINCONF$',  trim(left("&MINCONF.")));
	long = tranwrd(long, '$SUPPORT$',  trim(left("&SUPPORT.")));
	long = tranwrd(long, '$MAXOBS$',  trim(left("&MAXOBS.")));
	long = tranwrd(long, '$_PROGRAM$',  trim(left("&_PROGRAM.")));
	long = tranwrd(long, '$CAT$',  trim(left("&CAT.")));
	if "&CRIT."	 = "conf" then          long = tranwrd(long, '$CRIT_CONF$',     "selected");
	else if "&CRIT."	 = "support" then long = tranwrd(long, '$CRIT_SUPPORT$',  "selected");
	else if "&CRIT."	 = "lift" then    long = tranwrd(long, '$CRIT_LIFT$',     "selected");
	else                                long = tranwrd(long, '$CRIT_COUNT$',    "selected");
	
	long = trim(long);
	put long ' ';
cards4;
	<table width="100%" border=0>
		<tr style='background:#cccccc'>
			<td colspan=11><h3>Weitere Parameter zum Fine-Tuning</h3></td>
		</tr>
		<tr style='background:#cccccc'>
			<form method="post" action="do">
				<input type='hidden' name='_action' value='form,execute,nobanner'>
				<input type='hidden' name='_program' value='$_PROGRAM$'>
				<input type='hidden' name='CAT' value='$CAT$'>
			<td>Anzahl Artikel pro Regel</td>      <td><input type=text name='ITEMS' style='width:30px' value='$ITEMS$'/></td>
			<td>Untergrenze f&uuml;r Konfidenz</td><td><input type=text name='MINCONF' style='width:30px' value='$MINCONF$'/></td>
			<td>Untergrenze f&uuml;r Support</td>  <td><input type=text name='SUPPORT' style='width:30px' value='$SUPPORT$'/></td>
			<td>Maximale Anzahl Regeln</td>        <td><input type=text name='MAXOBS' style='width:30px' value='$MAXOBS$'/></td>
			<td>Sortierungskriterium f&uuml;r Regelanzeige</td>
				<td><select name='CRIT' style='width:70px' size=1>
							<option $CRIT_CONF$>conf</option>
							<option $CRIT_SUPPORT$>support</option>
							<option $CRIT_LIFT$>lift</option>
							<option $CRIT_COUNT$>count</option>
						</select>
			</td>
			<td><input type='submit' value="Neu berechnen"/></td>
			</form>
		</tr>
		<tr>
			<td colspan=11>&nbsp;</td>
		</tr>
		<tr>
			<td colspan=11>
;;;;
run;

%stpbegin;
%mdisplay;
%stpend; 

data _null_;
	file &WEBOUT.;
	length long $1024;
	input;
	long = _infile_;
	long = trim(long);
	put long ' ';
cards4;
			</td>
		</tr>
	</table>
;;;;
run;

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten); 
;*';*";*/;quit; 
*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);