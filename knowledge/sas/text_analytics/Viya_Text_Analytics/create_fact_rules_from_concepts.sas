%let Path= c:\Public;

data Teil;
	input Teil $27.;
	datalines;
JD_Haube_Grill
JD_Abgasanlage
JD_Motor
JD_Ventil_Kuppler
JD_Kraftstofftank
JD_SIDIS
JD_Kotschuetzer_Verbreitung
JD_Kaeltemittel
;

proc print;
run;

data Ort;
	input Ort $12.;
	datalines;
JD_Links
JD_Rechts
JD_Vorne
JD_Hinten
JD_Oben
JD_Unten
JD_Innen
JD_Zwischen
JD_Ueber
JD_Vorne
JD_Neben
JD_Seitlich
JD_Unterhalb
JD_Mitte
JD_Aussen
;

proc print;
run;

data Defekt;
	input Defekt $30.;
	datalines;
JD_Verlegung_MontageFalsch
JD_Nicht_Eingestellt
JD_Unsauber
JD_Nicht_Gesichert
JD_Materialfehler_Porös
JD_Spalt
JD_Manpower
JD_Kalibrierung
JD_Geraeusche
JD_E_Fehler
JD_Programmierung_Falsch_Fehlt
JD_Klemmt_Schwergaengig
JD_Nicht_Ausgerichtet
JD_Nicht_Freiliegend
JD_Passt_Nicht
JD_Falsch
JD_Lose
JD_Lachfehler_Oberflaeche
JD_Nicht_Geprueft
JD_Abgeknickt
JD_Abgebrochen
JD_Beschaedigt
JD_Kratzer
JD_Abgerissen
JD_Delle
JD_Verbogen
JD_Verformt
JD_Fehlteil
JD_Fehlt
JD_Undicht
JD_Funktionsfehler
;

proc print;
run;

proc sql noprint;
	create Table Sequence_Rules_LITI as 
		select l.*,m.*,r.*, 
			'SEQUENCE:(part, defect, where):_part{'||strip(Teil)||'} _w _defect{'||strip(Defekt)||'} _w _where{'||strip(Ort)||'}' length=256 as Sequence
		from Teil as l,Ort as m, Defekt as r;
quit;

filename outfile "&path.\Seq_Rules_LITI.dat";

data _null_;
	set Sequence_Rules_LITI;
	file outfile encoding="utf-8";
	put sequence;
run;