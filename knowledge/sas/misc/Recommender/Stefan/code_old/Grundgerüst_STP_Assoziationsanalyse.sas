/* Verweis auf das Verzeichznis der SAS Tabelle Bondaten_baumarkt */
%let fpath=C:\Daten\QUELLEN;
libname outlib "&fpath";

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
%let cat=Garten & Balkon;

/* Anzahl Artikel pro Regel: Integer-Wertebereich von 2-4 (Voreinstellung 2) */
%let items=3;

/* Untergrenze für Konfidenz: Integer-Wertebereich von 2-99 (Voreinstellung 5) */
%let minconf=15;

/* Untergrenze für Support: Integer-Wertebereich von 10-1000 (Voreinstellung 50) */
%let support=10;

/* Maximale Anzahl Regeln: Integer-Wertebereich von 10-200 (Voreinstellung 50) */
%let maxobs=100;

/* Sortierungskriterium für Regelanzeige: aus Kategorien: conf (Voreinstellung), support, lift, count*/
%let crit=conf;

/* Sample Code Assoc*/
data x;
	set DATA.Bondaten_baumarkt;
	where KATEGORIE="&cat";
run;

/* Run the DMDB Procedure */
proc dmdb batch data=x
	dmdbcat=DATA.catRule;
	id trans_id;
	class artname(desc);
run;

/* Run the ASSOC Procedure */
proc assoc data=x
	dmdbcat=DATA.catRule out=assocOut
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
		set_size="Anzahl Artikel in Regel"
		rule ="Regelbeschreibung"
		count="Anzahl Transaktionen"
		support ="In % der Transaktionen (Support in %)"
		conf ="Konfidenz (bedingte Wahrscheinlichkeit für rechte Regel-Seite)"
		exp_conf="Erwartete Konfidenz (bei Unabhängigkeit)"
		lift ="Lift (=Konfidenz/erwart. Konfidenz)";
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
	label rule_id='Regelnummer';
run;

/* Macro fängt Situation ab, bei der keine Regel gefunden wird */
%macro mdisplay;
	title "Gefundene Assoziationsregeln für Kategorie: &cat";
	title2 "Maximale Anzahl Artikel pro Regel: &items";
	title3 "Untergrenze für Konfidenz: &minconf.% und Mindestanzahl Transaktionen pro Regel (Support): &support";
	title4 "Sortiert nach: &slabel";

	%if %eval(&set)=1 %then
		%do;

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

			proc print data=results2 noobs label width=full;
				var rule_id set_size count rule support conf exp_conf lift;
			run;

			title;
			title2;
			title3;
		%end;
%mend;

%mdisplay;

/* Ende des Stored Process (man könnte die Liste der generierten Regeln noch als Download für Excel anbieten,
 müsste dann den Code noch mal anpassen )*/