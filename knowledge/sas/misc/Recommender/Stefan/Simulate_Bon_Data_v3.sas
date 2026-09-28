/* Pfad für Ablage der Rohdaten (CSV-Dateien) */
%let fpath=C:\Codes\Recommender\Stefan;

/* Pfad für Speicherort der Pre-Assigned Library */
libname outlib "C:\Codes\Recommender\Stefan";

proc import file="&fpath\Verbundkaufsimulation.xlsx" dbms=XLSX replace out=tmp0;
	sheet='Regeln';
run;

data tmp0;
	set tmp0;
	x=ranuni(11111);

	if _n_<20 then
		FLAG=1;
	else if _n_<30 then
		FLAG=2;
	else FLAG=3;
run;

proc sql;
	create table tmp0a as 
		select
			distinct(UID_RE) as UID from tmp0 
				union 
			select distinct(UID_LI) as UID from tmp0
	;
quit;

data tmp0b;
	set tmp0a;

	if _n_<30 then
		FLAG_RULE=1;
	else if _n_<50 then
		FLAG_RULE=2;
	else FLAG_RULE=3;
run;

/* Importiere Rohdaten und bereite sie auf */
DATA tmp1;
	LENGTH
		F1               $ 15
		F2               $ 86
		F3               $ 87
		F4               $ 84
		F5               $ 7
		F6               $ 21
		F7               $ 7
		F8               $ 1;
	FORMAT
		F1               $CHAR15.
		F2               $CHAR86.
		F3               $CHAR87.
		F4               $CHAR84.
		F5               $CHAR7.
		F6               $CHAR21.
		F7               $CHAR7.
		F8               $CHAR1.;
	INFORMAT
		F1               $CHAR15.
		F2               $CHAR86.
		F3               $CHAR87.
		F4               $CHAR84.
		F5               $CHAR7.
		F6               $CHAR21.
		F7               $CHAR7.
		F8               $CHAR1.;
	INFILE "&fpath\Baumarkt_2.dat"
		LRECL=1024
		ENCODING="WLATIN1"
		TERMSTR=CRLF
		DLM=';'
		MISSOVER
		DSD;
	INPUT
		F1               : $CHAR15.
		F2               : $CHAR86.
		F3               : $CHAR87.
		F4               : $CHAR84.
		F5               : $CHAR7.
		F6               : $CHAR21.
		F7               : $CHAR7.
		F8               : $CHAR1.;
RUN;

data tmp2;
	set tmp1;
	ARTNAME=f2;
	KATEGORIE=scan(f3,1,'>');
	HAUPTGRUPPE=scan(f3,2,'>');
	UNTERGRUPPE=scan(f3,3,'>');
	PREIS_REG=input(f4,6.2);

	if PREIS_REG>5 then
		PREIS_REG=PREIS_REG+int(ranuni(23123))*5-2.5;
	drop f1 f2 f3 f4 f5 f6 f7 f8;

	if missing(PREIS_REG) then
		delete;
run;

data tmp3;
	set tmp2;
	KATEGORIE=strip(KATEGORIE);
	HAUPTGRUPPE=strip(HAUPTGRUPPE);
	UNTERGRUPPE=strip(UNTERGRUPPE);
	UID=_n_;
run;

proc sql;
	create table tmp4 as select 
		a.*,
		b.FLAG_RULE
	from tmp3 as a left join tmp0b as b on a.uid=b.uid
		order by a.KATEGORIE, a.HAUPTGRUPPE, a.UNTERGRUPPE;
quit;

data tmp5;
	set tmp4;
	where flag_rule in (1,2,3) or ranuni(344)<0.5 or UNTERGRUPPE in 
		('Außenleuchten', 
		'Sonnenschirme und -segel',
		'Grill-Zubehör',
		'Holzkohlegrills',
		'Rasentrimmer und Sensen',
		'Garten- und Baumscheren',
		'Benzin-Rasenmäher',
		'Pflanztöpfe, -kübel und -schalen'
			);
	retain KATNO HGNO UGNO;

	if first.KATEGORIE then
		KATNO+1;

	if first.HAUPTGRUPPE then
		HGNO+1;

	if first.UNTERGRUPPE then
		UGNO+1;
	by KATEGORIE HAUPTGRUPPE UNTERGRUPPE;
	KAT_KEY=KATNO;
	HG_KEY=KATNO*1000+HGNO;
	UG_KEY=KATNO*100000+HGNO*1000+UGNO;
	ARTNO=UG_KEY*10000000+_n_;
	format ARTNO 16.0;
run;

/* Selektiere Artikel und generiere künstliche Häufigkeiten pro Artikel (abhängig von Preis)*/
data tmp6;
	set tmp5;

	if      preis_reg<10 then
		freq=500+int(rangam(1234,12)*6);
	else if preis_reg<50 then
		freq=250+int(rangam(2345,5)*4);
	else                      freq=40+int(ranpoi(3456,5));

	/* Hier künstliche Häufigkeiten für Verbundkauf mit Aktionsartikel Deutschland-Flagge einfügen */
	if uid in (599, 4708, 6531, 220) then
		freq=500+ranpoi(2222,5);

	/* Hier sonstige künstliche Häufigkeiten für Verbundkauf einfügen */
	if flag_rule=1 then
		freq=500+int(rannor(1234)*20);

	if flag_rule=2 then
		freq=250+int(rannor(1234)*50);

	if flag_rule=3 then
		freq=100+int(rannor(1234)*20);
	ARTNAME=cat('Art.Nr.',put(UID,z5.0),' ', ARTNAME);
	lfd=_n_;
run;

proc sql noprint;
	select count(*) into:maxobs from tmp6;
quit;

/* Generiere Basis-Tabelle für Transaktionen (aus Häufigkeiten)*/
data tmp7;
	set tmp6;

	do i = 1 to &maxobs;
		do j=1 to 600;
			if i =1 and j<=freq then
				output;
			else delete;
		end;
	end;
run;

/* Zufällige Sortierung */
data tmp8;
	set tmp7;
	ransel=ranuni(111);
	drop i j;
run;

proc sort data=tmp8;
	by ransel;
run;

data tmp9;
	set tmp8;
	retain xxx_id 0;

	if ranuni(123) > 0.6 then
		xxx_id+1;
	format xxx_id z8.0;
	drop freq ransel;

	/*flag für HG Bodenbeläge */
	if hgno=8 then
		flg=1;
	else flg=0;
run;

proc sql;
	create table tmp10 as select
		distinct (xxx_id) as xxx_id,
			sum(flg) as sumflg,
			count(distinct artno) as cnt_dist,
			sum(preis_reg) as umsatz

		from tmp9
			group by xxx_id;
quit;

data tmp11;
	set tmp10;
	x1=ranuni(7);
	x2=ranuni(8);
	x3=ranuni(9);

	/* Datum fixieren */
	DATUM='02MAY2012'D+int(ranuni(235)*30);
	y=ranpoi(2,2)*4;

	if DATUM>'01JUN2012'D then
		DATUM='01JUN2012'D-y;

	if DATUM='01MAY2012'D then
		DATUM=DATUM+1+int(ranuni(232)*5);
	z=ranuni(1);

	if weekday(DATUM)=1 and z<0.6 then
		DATUM=DATUM-1;

	if weekday(DATUM)=1 and z>=0.6 then
		DATUM=DATUM-2;
	format DATUM date9.;

	/* Uhrzeit (Bodenbeläge morgens !) */
	if sumflg=1 then
		UHRZEIT=3600*8+int(ranuni(434)*1000);
	else if x1<0.3 then
		UHRZEIT=3600*8+int(ranuni(434)*3600*ranpoi(1234,2));
	else if x1<0.6 then
		UHRZEIT=3600*8+2+ int(ranuni(434)*3600*ranpoi(1233,3));
	else                UHRZEIT=3600*8+int(ranuni(434)*3600*12);

	if UHRZEIT > 3600*8*3600*12 then
		UHRZEIT =3600*8*3600*12-int(ranuni(123)*10);
	format UHRZEIT time.;
	FID=int(ranuni(4)*30)+1;

	if x2<=0.7 then
		FID=4+int(ranuni(3)*18);

	if x3>=0.8 then
		FID=20+int(ranuni(22)*3);

	if (umsatz > 50 or cnt_dist>3) and ranuni(23423)>0.8 then
		FID=3;
	drop x1 x2 x3 y z;
run;

proc sql noprint;
	select max(FID) into: maxfil from tmp11;
quit;

/* Geo-Daten einspielen */
data tmp12;
	infile "&fpath\PLZ.TXT" DELIMITER='09'x MISSOVER DSD;
	input
		Primaerschluessel : $5.
		PLZ : $5.
		LAENGENGRAD : 8.
		BREITENGRAD : 8.
		FILIALE : $40.;
	y=_n_;

	if y not in (18,1560,1431, 2079,2213,2449,2954, 3024, 3161, 3404,3600,3655,3882,4276,4458, 4603, 4888, 4920,4973,
		5550, 5744,5806,5956,6400, 7100,7928, 8189, 148,1106,680) then
		delete;
	drop primaerschluessel y;
run;

/* Selektiere bestimmte Filialnummern */
data tmp13;
	set tmp12;
	FID=_n_;
	length REGION $12.;

	if Filiale in ('Dresden','Cottbus','Berlin','Rostock','Magdeburg','Erfurt') then
		REGION='Ost';

	if Filiale in ('Hamburg','Bremen','Kiel','Hannover') then
		REGION='Nord';

	if Filiale in ('Bielefeld','Düsseldorf','Dortmund','Aachen', 'Münster', 'Köln') then
		REGION='NRW';

	if Filiale in ('Mainz','Frankfurt am Main','Darmstadt','Mannheim', 'Karlsruhe', 'Stuttgart',
		'Heidelberg','Konstanz', 'Freiburg im Breisgau', 'Saarbrücken') then
		REGION='Südwest';

	if Filiale in ('München','Würzburg','Nürnberg','Ingolstadt') then
		REGION='Bayern';
run;

proc sql;
	create table tmp14 as select
		a.xxx_id,
		a.DATUM,
		a.UHRZEIT,
		b.FILIALE,
		b.REGION,
		b.LAENGENGRAD,
		b.BREITENGRAD
	from tmp11 as a left join tmp13 as b on a.FID=b.FID
		order by a.xxx_id;
quit;

proc sql;
	create table tmp15 as select
		a.xxx_id,
		b.DATUM,
		b.UHRZEIT,
		b.FILIALE,
		b.REGION,
		b.LAENGENGRAD,
		b.BREITENGRAD,
		a.ARTNO,
		a.ARTNAME,
		a.KATEGORIE,
		a.HAUPTGRUPPE,
		a.UNTERGRUPPE,
		a.PREIS_REG,
		a.UID
	from tmp9 as a left join tmp14 as b on a.xxx_id=b.xxx_id;
quit;

data tmp16;
	set tmp15;

	if ranuni(44)<0.8 then
		ANZ_VE=1;
	else ANZ_VE=ranpoi(3,2)*2+1;

	/* Promotions einbauen */
	if ranuni(111)<0.03 then
		do;
			if ranuni(41) >0.5 then
				ANZ_VE=ANZ_VE*2;

			if ranuni(44)>0.5 then
				PREIS_PROMO=round(PREIS_REG*0.66,0.99);
			else PREIS_PROMO=round(PREIS_REG*0.5,0.99);
			AKTION=1;
		end;
	else
		do;
			AKTION=0;
			PREIS_PROMO=PREIS_REG;
		end;

	NETTOUMSATZ=PREIS_PROMO*ANZ_VE;
	format NETTOUMSATZ 8.2;
	label ARTNAME='Artikelbezeichnung'
		ARTNO='Artikelnummer'
		KATEGORIE='Warenkategorie'
		HAUPTGRUPPE='Artikelhauptgruppe'
		UNTERGRUPPE='Artikeluntergruppe'
		PREIS_REG='VK-Preis (regulär)'
		PREIS_PROMO='VK-Preis (Promotion)'
		DATUM='Datum'
		UHRZEIT='Zeitstempel'
		FILIALE='Filiale'
		REGION='Vertriebsregion'
		ANZ_VE='Anzahl VE'
		LAENGENGRAD='Längengrad'
		BREITENGRAD='Breitengrad'
		AKTION='Flag für Aktionsartikel'
		NETTOUMSATZ='Nettoumsatz'
	;
run;

/* Zusätzlichen Artikel WM Flagge einfügen*/
data tmp17;
	set tmp16;
	where uid in (599, 4708, 6531, 220) and ranuni(1232)<0.9;
	ARTNAME ='Art.Nr.09999 Deutschland-Fahne 2.0m x 1.5m';
	KATEGORIE='Garten & Balkon';
	HAUPTGRUPPE='Balkon & Terasse';
	UNTERGRUPPE='Trendartikel';
	ARTNO=9999999999999;
	PREIS_REG=13.99;
	PREIS_PROMO=10.99;
	AKTION=1;

	if ranuni(123)<0.9 then
		ANZ_VE=1;
	else ANZ_VE=1+ranpoi(123,2);
	NETTOUMSATZ=ANZ_VE*PREIS_PROMO;
run;

/* Generiere Daten für zusätzliche Artikel und füge Regeln für Verbundkäufe ein */
proc sql;
	create table tmp18 as select 
		a.xxx_id,
		a.DATUM,
		a.UHRZEIT,
		a.FILIALE,
		a.REGION,
		a.LAENGENGRAD,
		a.BREITENGRAD,
		a.UID,
		b.UID_LI,
		b.UID_RE,
		b.x

	from tmp16 as a right join tmp0 as b on a.UID =b.UID_LI;
quit;

data tmp18;
	set tmp18;
	y=max(1,0.7+ranuni(11111));
	z=x*y;

	/* Hier Regeln für künstliche Verbundkäufe einfügen */
	if z>0.15 then
		uid2=uid_re;

	if uid2=. then
		delete;
run;

proc sql;
	create table tmp19 as select 
		a.xxx_id,
		a.uid2,
		b.uid,
		a.DATUM,
		a.UHRZEIT,
		a.FILIALE,
		a.REGION,
		a.LAENGENGRAD,
		a.BREITENGRAD,
		b.ARTNO,
		b.ARTNAME,
		b.KATEGORIE,
		b.HAUPTGRUPPE,
		b.UNTERGRUPPE,
		b.PREIS_REG
	from tmp18 as a left join tmp6 as b on a.uid2=b.uid;
quit;

data tmp20;
	set tmp19;

	if ranuni(44)<0.8 then
		ANZ_VE=1;
	else ANZ_VE=1+ranpoi(3,2)*2+1;

	if Preis_reg>200 and ranuni(45)>0.01 then
		ANZ_VE=1;

	/* Promotions einbauen */
	if ranuni(111)<0.03 then
		do;
			if ranuni(41) >0.5 then
				ANZ_VE=ANZ_VE*2;

			if ranuni(44)>0.5 then
				PREIS_PROMO=round(PREIS_REG*0.66,0.99);
			else PREIS_PROMO=round(PREIS_REG*0.5,0.99);
			AKTION=1;
		end;
	else
		do;
			AKTION=0;
			PREIS_PROMO=PREIS_REG;
		end;

	NETTOUMSATZ=PREIS_PROMO*ANZ_VE;
	format NETTOUMSATZ 8.2;
run;

data tmp21;
	set tmp16 tmp17 tmp20;

	/* Künstliche Käufe für Aktionsartikel */
	if ranuni(5678)>0.99 then
		do;
			ARTNAME ='Art.Nr.09999 Deutschland-Fahne 2.0m x 1.5m';
			KATEGORIE='Garten & Balkon';
			HAUPTGRUPPE='Balkon & Terasse';
			UNTERGRUPPE='Trendartikel';
			ARTNO=9999999999999;
			PREIS_REG=13.99;
			PREIS_PROMO=10.99;
			AKTION=1;

			if ranuni(123)<0.9 then
				ANZ_VE=1;
			else ANZ_VE=1+ranpoi(123,2);
			NETTOUMSATZ=ANZ_VE*PREIS_PROMO;
		end;

	drop uid;
run;

proc sort data=tmp21;
	by xxx_id ARTNO;
run;

data tmp22;
	set tmp21;
	ransel=ranuni(1111);

	/* Dubletten herausnehmen */
	if xxx_id=lag(xxx_id) and ARTNO=lag(ARTNO) then
		delete;
run;

proc sort data=tmp22 out=tmp23;
	by datum xxx_id ransel;
run;

/* Erstellen der finalen Tabelle */
data BONDATEN_BAUMARKT;
	set tmp23;
	PREIS_EK = PREIS_REG * (0.6+ranuni(222)/5);
	format PREIS_EK 8.2;
	TRANS_ID=500000000+int(ranuni(123))*9999999+xxx_id;

	if first.xxx_id then
		do;
			BONPOSITION=1;
		end;
	else
		do;
			BONPOSITION+1;
		end;

	Length WOCHENTAG $15.;

	if weekday(DATUM)=1 then
		WOCHENTAG='0. Sonntag';
	else if weekday(DATUM)=2 then
		WOCHENTAG='1. Montag';
	else if weekday(DATUM)=3 then
		WOCHENTAG='2. Dienstag';
	else if weekday(DATUM)=4 then
		WOCHENTAG='3. Mittwoch';
	else if weekday(DATUM)=5 then
		WOCHENTAG='4. Donnerstag';
	else if weekday(DATUM)=6 then
		WOCHENTAG='5. Freitag';
	else if weekday(DATUM)=7 then
		WOCHENTAG='6. Samstag';
	label BONPOSITION = "Bon-Position"
		TRANS_ID ="Transaktions-ID"
		PREIS_EK = "EK-Preis";
	by datum xxx_id ransel;
	drop xxx_id ransel uid2;
run;

proc copy in=work out=outlib;
	select BONDATEN_BAUMARKT;
run;

/* Cross Tab sicht */
proc sql;
	create table tmp24 as select
		distinct a.ARTNAME label "Artikel 1" as ARTIKEL1,
			a.KATEGORIE label "Warenkategorie 1" as KATEGORIE1,
			a.HAUPTGRUPPE label "Hauptgruppe 1" as HAUPTGRUPPE1,
			a.UNTERGRUPPE label "Untergruppe 1" as UNTERGRUPPE1,
			sum(a.NETTOUMSATZ) label "Nettoumsatz 1" as NETTOUMSATZ1,
			sum(a.AKTION) label "Anzahl Aktionen 1" as ANZ_AKTIONEN1,
			sum((a.PREIS_PROMO-a.PREIS_EK)*a.ANZ_VE) label "Spanne 1" format 16.2 as SPANNE1,

			b.ARTNAME label "Artikel 2" as ARTIKEL2,
			b.KATEGORIE label "Warenkategorie 2" as KATEGORIE2,
			b.HAUPTGRUPPE label "Hauptgruppe 2" as HAUPTGRUPPE2,
			b.UNTERGRUPPE label "Untergruppe 2" as UNTERGRUPPE2,
			sum(b.NETTOUMSATZ) label "Nettoumsatz 2" as NETTOUMSATZ2,
			sum(b.AKTION) label "Anzahl Aktionen 2" as ANZ_AKTIONEN2,
			sum((b.PREIS_PROMO-b.PREIS_EK)*b.ANZ_VE) label "Spanne 2" format 16.2 as SPANNE2,


			count(distinct a.TRANS_ID) label "Anzahl Transaktionen" as ANZAHL_TRANS,
			(sum(a.Nettoumsatz)+sum(b.NETToumsatz)) label "Nettoumsatz" as NETTOUMSATZ,
			sum((a.PREIS_PROMO-a.PREIS_EK)*a.ANZ_VE)+sum((b.PREIS_PROMO-b.PREIS_EK)*b.ANZ_VE) format 16.2 label "Spanne" as SPANNE


		from BONDATEN_BAUMARKT as a left join BONDATEN_BAUMARKT as b on a.TRANS_ID=b.TRANS_ID 
			where lengthn(a.ARTNAME)>0 and lengthn(b.ARTNAME)>0

			group by a.ARTNAME, b.ARTNAME;
quit;

data tmp25;
	set tmp24;

	if ARTIKEL1 = ARTIKEL2 then
		delete;
run;

%include "C:\Daten\SALES_PUSH_2014\Bondatenanalyse\Assoziationsanalyse_komplettedaten.sas";

proc sql;
	create table tmp26 as select
		a.*,
		b.rule_id label "Regel: Regel-ID" as RULE_ID,
		b.EXP_CONF label "Regel: Erwartete Konfidenz",
		b.CONF label "Regel: Konfidenz",
		b.SUPPORT label "Regel: Support in %",
		b.LIFT "Regel: Lift-Faktor",
		b.RULE "Regel: Regelbeschreibung",
		b.COUNT "Regel: Anzahl Transaktionen"
	from tmp25 as a left join DATA.assocresults_final as b 
		on a.ARTIKEL1 = b._LHAND and a.ARTIKEL2 = b._RHAND
	order by a.ARTIKEL1,  a.ARTIKEL2;
quit;

data BONDATEN_BAUMARKT_CROSSTAB;
	set tmp26;

	if lengthn(rule)=0 then
		FLAG_RULE=0;
	else FLAG_RULE=1;
	label FLAG_RULE='Regel: Flag für gefundene Assoziationsregel';
run;

proc copy in=work out=outlib;
	select BONDATEN_BAUMARKT BONDATEN_BAUMARKT_CROSSTAB;
run;