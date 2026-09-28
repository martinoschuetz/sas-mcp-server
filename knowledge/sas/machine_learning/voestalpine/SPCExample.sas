/* Changed:
- Use simulated data since test computer doesn't have QC installed.
- SQL to FEDSQL sessref=mysess;
- 9.4 libs to CASLIBS
- einmalwerte5808 to einmalwerte_9826
- segmentwerte8884 to segmentwerte_9826
- IFN to CASE statement
- PROC SPC: 
* ProcessName necessary, subgroupvalue hier Monat_BBS muss numerisch sein
 * CAS benötigt keine Sortierung mehr
- Sort has to be substitued by by-group processing. Not necessary for proc SPC
*/
options mprint;

/* start a CAS session and assign the libnames */
options cashost="dach-viya-smp.sas.com" casport=5570;
cas mysess sessopts=(timeout=1800 metrics=true);
caslib _all_ assign;

/*Datenauszug aus JOIN EINAMLWERTE UND SEGMENTWERTE verknüpft über Bandnr*/
/*%delete_table(lib=public,ds=DB1);*/
proc casutil;
	droptable incaslib=public casdata="DB1" quiet;
run;

PROC FEDSQL sessref=mysess;
	CREATE TABLE PUBLIC.DB1 AS 
		SELECT 	'1' as ProcessName,
			cat1 as LEITGUETEBB,
			cat100 as BANDNR,
			abs(round(inf1)) as Monat_BBS,
			abs(inf2+noise2) as ZUF_OS_FL_FILET,
			abs(inf3+noise3)/1000 as Betroffengr100_OS_Filet
		FROM casdata.simulated_row7000_col1500;
QUIT;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 1*/
/*Shewhart X-S-CHART mit 3 SIGMA Level getrennt nach LEITGUETEBB - diese Trennung nach Leitgüte sollte interaktiv passieren mit den "Actions"*/
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/* Columns processname and subgroupname partition the data for one control chart.*/
proc casutil;
	droptable incaslib=public casdata="xschart_bsp1_outlimits" quiet;
	droptable incaslib=public casdata="xschart_bsp1_outtable" quiet;
run;

proc spc data=public.db1 
	processname=ProcessName subgroupname=LEITGUETEBB subgroupvalue=Monat_BBS processvalue=ZUF_OS_FL_FILET;
	xschart / 	tests=1 to 8 tests2=1 to 8
		outlimits=casuser.xschart_bsp1_outlimits outtable=casuser.xschart_bsp1_outtable;
run;

/* Work around for current bug bug in pre-release*/
data casuser.xschart_bsp1_outtable;
	set casuser.xschart_bsp1_outtable;
	retain LEITGUETEBB;
	LEITGUETEBB = 1;

	if _n_ > 116 then
		LEITGUETEBB = 2;
run;

proc casutil;
	promote incaslib=casuser casdata="xschart_bsp1_outlimits" outcaslib=public;
	promote incaslib=casuser casdata="xschart_bsp1_outtable" outcaslib=public;
quit;

/* Classical QC approach requires sorting */
PROC SQL;
	CREATE VIEW WORK.SORTTemp2 AS
		SELECT T.ZUF_OS_FL_FILET, T.Monat_BBS, T.LEITGUETEBB, ProcessName
			FROM public.DB1 as T ORDER BY T.ProcessName, T.LEITGUETEBB, T.Monat_BBS;
QUIT;

TITLE;
TITLE1 "Shewhart-Analyse von: ZUF_OS_FL_FILET*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTemp2;
	XSCHART 	 (ZUF_OS_FL_FILET)	* Monat_BBS	/
		OUTTABLE=work.SHEW_XSChart
		SIGMAS=3
		CAXIS=BLACK
		WAXIS=1
		CTEXT=BLACK
		CINFILL=CXA9A9A9
		CLIMITS=BLACK
		TOTPANELS=1
		CCONNECT=BLUE
		COUT=RED
		COUTFILL=RED
		CFRAME=CXD3D3D3;
	BY LEITGUETEBB;;
RUN;

QUIT;

TITLE;
FOOTNOTE;

/* Gruppierung nach Monat für p und u chart*/
proc casutil;
	droptable incaslib=public casdata="QUERY1" quiet;
run;

PROC FEDSQL sessref=mysess;
	CREATE TABLE PUBLIC.QUERY1 AS 
		SELECT t1.ProcessName, t1.LEITGUETEBB, t1.Monat_BBS, 
			(MEAN(t1.Betroffengr100_OS_Filet)) AS MEAN_of_Betroffengr100_OS_Filet,  
			(COUNT(t1.BANDNR)) AS COUNT_of_BANDNR,
			(SUM(t1.Betroffengr100_OS_Filet)) AS SUM_of_Betroffengr100_OS_Filet
		FROM PUBLIC.DB1 t1
			GROUP BY t1.ProcessName, t1.LEITGUETEBB, t1.Monat_BBS;
QUIT;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 a.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit SIGMAS=3
  ------------------------------------------------------------------- */

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/* Columns processname and subgroupname partition the data for one control chart.*/
proc casutil;
	droptable incaslib=public casdata="pchart_bsp2a_outlimits" quiet;
	droptable incaslib=public casdata="pchart_bsp2a_outtable" quiet;
run;

proc spc data=public.query1 
	processname=ProcessName subgroupname=LEITGUETEBB subgroupvalue=Monat_BBS processvalue=SUM_of_Betroffengr100_OS_Filet;
	pchart / 	sigmas=3 subgroupn=COUNT_of_BANDNR tests=1 to 8
		outlimits=casuser.pchart_bsp2a_outlimits outtable=casuser.pchart_bsp2a_outtable;
run;

/* Work around for current bug bug in pre-release*/
data casuser.pchart_bsp2a_outtable;
	set casuser.pchart_bsp2a_outtable;
	retain LEITGUETEBB;
	LEITGUETEBB = 1;

	if _n_ > 116 then
		LEITGUETEBB = 2;
run;

proc casutil;
	promote incaslib=casuser casdata="pchart_bsp2a_outlimits" outcaslib=public;
	promote incaslib=casuser casdata="pchart_bsp2a_outtable" outcaslib=public;
quit;

/**************************** ORIGINAL VERSION *********************************************/
PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT 	sum(T.SUM_of_Betroffengr100_OS_Filet) as SUM_of_Betroffengr100_OS_Filet, 
				T.Monat_BBS, sum(T.COUNT_of_BANDNR) as COUNT_of_BANDNR
			FROM PUBLIC.QUERY1 as T	group by T.Monat_BBS ORDER BY T.Monat_BBS;
QUIT;


TITLE;
TITLE1 "Shewhart-Analyse von: SUM_of_Betroffengr100_OS_Filet*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTempTableSorted
;
	PChart 	 (SUM_of_Betroffengr100_OS_Filet)	* Monat_BBS	/
		OUTTABLE=WORK.SHEW_Pchart_mit3sigma(LABEL="Regelkarte Untergruppenstatistiken und Regelgrenzen für WORK.QUERY_FOR_EINMALWERTE_0000")
		SIGMAS=3
		TESTS= 1 2 3 4 CTESTS=RED
		TESTLABEL1='Etikett für Test 1'
		TESTLABEL2='Etikett für Test 2'
		TESTLABEL3='Etikett für Test 3'
		TESTLABEL4='Etikett für Test 4'
		CAXIS=BLACK
		WAXIS=1
		CTEXT=BLACK
		CINFILL=CXA9A9A9
		CLIMITS=BLACK
		TOTPANELS=1
		CCONNECT=BLUE
		COUT=RED
		COUTFILL=RED
		CFRAME=CXD3D3D3
		SUBGROUPN=COUNT_of_BANDNR;
	;
RUN;

QUIT;

TITLE;
FOOTNOTE;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 b.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit SIGMAS=0.5
 ------------------------------------------------------------------- */

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
TITLE;
TITLE1 "Shewhart-Analyse von: SUM_of_Betroffengr100_OS_Filet*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTempTableSorted
;
	PChart 	 (SUM_of_Betroffengr100_OS_Filet)	* Monat_BBS	/
		OUTTABLE=WORK.SHEW_Pchart_mitsigma(LABEL="Regelkarte Untergruppenstatistiken und Regelgrenzen für WORK.QUERY_FOR_EINMALWERTE_0000")
		SIGMAS=0.5
		TESTS= 1 2 3 4 CTESTS=RED
		TESTLABEL1='Etikett für Test 1'
		TESTLABEL2='Etikett für Test 2'
		TESTLABEL3='Etikett für Test 3'
		TESTLABEL4='Etikett für Test 4'
		CAXIS=BLACK
		WAXIS=1
		CTEXT=BLACK
		CINFILL=CXA9A9A9
		CLIMITS=BLACK
		TOTPANELS=1
		CCONNECT=BLUE
		COUTFILL=RED
		CFRAME=CXD3D3D3
		SUBGROUPN=COUNT_of_BANDNR
	;
	;
RUN;

QUIT;

TITLE;
FOOTNOTE;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 c.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit alpha=0.617 (Pendant zu sigmas=0.5) 
 ------------------------------------------------------------------- */

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
TITLE;
TITLE1 "Shewhart-Analyse von: SUM_of_Betroffengr100_OS_Filet*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTempTableSorted
;
	PChart 	 (SUM_of_Betroffengr100_OS_Filet)	* Monat_BBS	/
		OUTTABLE=WORK.SHEW_Pchart_mitalpha(LABEL="Regelkarte Untergruppenstatistiken und Regelgrenzen für WORK.QUERY1")
		alpha=0.617
		actualalpha
		CAXIS=BLACK
		WAXIS=1
		CTEXT=BLACK
		CINFILL=CXA9A9A9
		CLIMITS=BLACK
		TOTPANELS=1
		CCONNECT=BLUE
		COUT=RED
		COUTFILL=RED
		CFRAME=CXD3D3D3
		SUBGROUPN=COUNT_of_BANDNR
	;
	;
RUN;

QUIT;

TITLE;
FOOTNOTE;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 d.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit alpha=0.617 (Pendant zu sigmas=0.5) und problimits=discrete
 ------------------------------------------------------------------- */

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
TITLE;
TITLE1 "Shewhart-Analyse von: SUM_of_Betroffengr100_OS_Filet*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTempTableSorted
;
	PChart 	 (SUM_of_Betroffengr100_OS_Filet)	* Monat_BBS	/
		OUTTABLE=WORK.SHEW_Pchart_mitalpha_discr(LABEL="Regelkarte Untergruppenstatistiken und Regelgrenzen für WORK.QUERY1")
		alpha=0.617
		actualalpha
		problimits=discrete
		CAXIS=BLACK
		WAXIS=1
		CTEXT=BLACK
		CINFILL=CXA9A9A9
		CLIMITS=BLACK
		TOTPANELS=1
		CCONNECT=BLUE
		COUT=RED
		COUTFILL=RED
		CFRAME=CXD3D3D3
		SUBGROUPN=COUNT_of_BANDNR
	;
	;
RUN;
QUIT;
TITLE;
FOOTNOTE;

/* Start building Dash-Board information */
/* Second table for building SPC-Dashboard */
proc casutil;
	droptable incaslib=public casdata="DB2" quiet;
run;

PROC FEDSQL sessref=mysess;
	CREATE TABLE PUBLIC.DB2 AS 
		SELECT cat150 as ProcessName,
			cat1 as LEITGUETEBB,
			cat100 as BANDNR,
			abs(round(inf1)) as Monat_BBS,
			abs(inf2+noise2) as ZUF_OS_FL_FILET,
			abs(inf3+noise3)/1000 as Betroffengr100_OS_Filet
		FROM public.simulated_row7000_col1500;
QUIT;

/* Columns processname and subgroupname partition the data for one control chart.*/
proc casutil;
	droptable incaslib=public casdata="xschart_dashboard_outlimits" quiet;
	droptable incaslib=public casdata="xschart_dashboard_outtable" quiet;
run;

proc spc data=public.db2 
	processname=ProcessName subgroupname=LEITGUETEBB subgroupvalue=Monat_BBS processvalue=ZUF_OS_FL_FILET;
	xschart / 	tests=1 to 8 tests2=1 to 8
		outlimits=casuser.xschart_dashboard_outlimits outtable=casuser.xschart_dashboard_outtable;
run;

proc casutil;
	promote incaslib=casuser casdata="xschart_dashboard_outlimits" outcaslib=public;
	promote incaslib=casuser casdata="xschart_dashboard_outtable" outcaslib=public;
quit;

proc freq data=public.xschart_dashboard_outtable;
	table _exlim_*_var_*LEITGUETEBB _exlims_*_var_*LEITGUETEBB;
run;

data test;
	set public.xschart_dashboard_outtable;
	if _var_ eq '3' and LEITGUETEBB eq '2';
run;

cas mysess terminate;