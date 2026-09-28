
proc sort data=fcslib.automotives out=tmp1;
 by region modell baureihe getriebe;
run;

PROC EXPAND DATA=tmp1
	OUT=TMP2
	FROM = MONTH
	TO = QTR
	ALIGN = BEGINNING
	METHOD = AGGREGATE
	OBSERVED = (TOTAL, TOTAL) ;

	BY region modell baureihe getriebe;
	ID zeitstempel;
	CONVERT absatz / 
	; 
	CONVERT preis / 
	; 
	CONVERT umsatz / 
	; 
	CONVERT varkost / 
	; 
	CONVERT fixkost / 
	; 
	CONVERT gewinn / 
	; 
	CONVERT db_ist / 
	; 
	CONVERT db_soll / 
	; 
	CONVERT db_delta / 
	; 
	CONVERT reklamationshoehe / 
	; 
	CONVERT reklamationsquote / 
	; 
	CONVERT rabatthoehe / 
	; 
	CONVERT finanzierung / 
	; 
	CONVERT navi / 
	; 
	CONVERT klima / 
	; 
	CONVERT mobilitaet / 
	; 
	CONVERT standzeit / 
	; 
 
run;

data tmp3; set tmp2;

retain marktanteil wachstum;
if first.getriebe then do;

marktanteil=ranuni(4324)/4;
wachstum=ranuni(5555)/10;
end;
else if modell in ('Performer','Bull Dog', 'Family') then do;
  marktanteil=marktanteil+abs(rannor(43656)/100);
  wachstum=wachstum+abs(rannor(4444)/100);
end;
else do;
 marktanteil=marktanteil+0.0005;
 wachstum=wachstum+abs(rannor(4444)/100);
end;
	BY region modell baureihe getriebe;

format marktanteil wachstum 8.4 ;

run;

data fcslib.automotives_qtr;
   set tmp3;
run;