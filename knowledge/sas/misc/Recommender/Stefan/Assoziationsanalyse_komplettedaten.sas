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
%let items=2;

/* Untergrenze für Konfidenz: Integer-Wertebereich von 2-99 (Voreinstellung 5) */
%let minconf=2;

/* Untergrenze für Support: Integer-Wertebereich von 10-1000 (Voreinstellung 50) */
%let support=1;

/* Maximale Anzahl Regeln: Integer-Wertebereich von 10-200 (Voreinstellung 50) */
%let maxobs=10000;

/* Sortierungskriterium für Regelanzeige: aus Kategorien: conf (Voreinstellung), support, lift, count*/
%let crit=conf;

/* Sample Code Assoc*/
data x;
	set DATA.Bondaten_baumarkt;

	* where KATEGORIE="&cat";
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
		set_size="Anzahl Artikel\in Regel"
		rule ="Regelbeschreibung"
		count="Anzahl\Transaktionen"
		support ="% der Transaktionen\(Support in %)"
		conf ="Konfidenz (bedingte Wahrschein-\lichkeit für rechte Regelseite)"
		exp_conf="Erwartete Konfidenz\bei Unabhängigkeit)"
		lift ="Lift (=Konfidenz/\erwartete Konfidenz)";
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

data DATA.ASSOCRESULTS_FINAL;
	set results2;
run;