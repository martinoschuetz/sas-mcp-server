/* start a CAS session and assign the libnames */
options mprint;
options cashost="dach-viya-smp.sas.com" casport=5570;
cas mysess sessopts=(timeout=1800 metrics=yes);
caslib _all_ assign;

proc contents data=public.simulated_row7000_col1500; run;

/* Changed:
	- SQL to FEDSQL sessref=mysess;
	- 9.4 libs to CASLIBS
	- einmalwerte5808 to einmalwerte_9826
	- segmentwerte8884 to segmentwerte_9826
	- IFN to CASE statement
	- PROC SPC: 
		* ProcessName necessary, subgroupvalue hier Monat_BBS muss numerisch sein
		* CAS benötigt keine Sortierung mehr
*/

libname mydata base "/home/sasdemo/sasdata";
libname mypublic cas sessref=mysess caslib=public;

%macro delete_table(lib=,ds=);
	%if %sysfunc(exist(&lib..&ds.,DATA)) %then %do;
		proc casutil;
			droptable incaslib=&lib. casdata="&ds.";
			deletesource incaslib=&lib. casdata="&ds.";
		quit;
	%end;
%mend;

/*Datenauszug aus JOIN EINAMLWERTE UND SEGMENTWERTE verknüpft über Bandnr*/

%delete_table(lib=public,ds=DB1);

PROC FEDSQL sessref=mysess;
   CREATE TABLE PUBLIC.DB1 AS 
   SELECT t2.BANDNR, 
          t2.PRODDATUM, 
          t1.TAGESDATUM_BBS, 
          t1.LEITGUETEBB, 
          t1.SORTMST,  
          t2.ZUF_OS_FL_FILET, 
          t2.ZUF_KLEIN_OS_FL_FILET, 
          t2.ZUF_OS_ANZ_FILET, 
          t2.ZUF_KLEIN_OS_ANZ_FILET, 
          t2.ZUF_US_FL_FILET, 
          t2.ZUF_KLEIN_US_FL_FILET, 
          t2.ZUF_US_ANZ_FILET, 
          t2.ZUF_KLEIN_US_ANZ_FILET, 
/*            (ifn(t2.ZUF_OS_ANZ_FILET>0,1,0)) AS Betroffen_OS_Filet, */
          case when t2.ZUF_OS_ANZ_FILET>0 then 1 else 0 end as Betroffen_OS_Filet,
/*            ((ifn(t2.ZUF_OS_ANZ_FILET>10,1,0))) AS Betroffengr10_OS_Filet, */
          case when t2.ZUF_OS_ANZ_FILET>10 then 1 else 0 end as Betroffengr10_OS_Filet,
/*            ((ifn(t2.ZUF_OS_ANZ_FILET>100,1,0))) AS Betroffengr100_OS_Filet, */
          case when t2.ZUF_OS_ANZ_FILET>100 then 1 else 0 end as Betroffengr100_OS_Filet,
          /* Monat_BBS */
 /*           (mdy(month(datepart(t1.TAGESDATUM_BBS)),1,year(datepart(t1.TAGESDATUM_BBS)))) FORMAT=monyy5. AS Monat_BBS*/
            year(datepart(t1.TAGESDATUM_BBS))*100 + month(datepart(t1.TAGESDATUM_BBS)) AS Monat_BBS,
           'Process1' as ProcessName
      FROM PUBLIC.einmalwerte_9826 t1
           INNER JOIN PUBLIC.segmentwerte_9826 t2 ON (t1.BANDNR = t2.BANDNR);
QUIT;

/* Gruppierung nach Monat für p und u chart*/

%delete_table(lib=public,ds=QUERY1);
PROC FEDSQL sessref=mysess;
   CREATE TABLE PUBLIC.QUERY1 AS 
   SELECT t1.Monat_BBS, 
            (MEAN(t1.Betroffen_OS_Filet)) AS MEAN_of_Betroffen_OS_Filet, 
            (MEAN(t1.Betroffengr10_OS_Filet)) AS MEAN_of_Betroffengr10_OS_Filet, 
            (MEAN(t1.Betroffengr100_OS_Filet)) AS MEAN_of_Betroffengr100_OS_Filet, 
            (COUNT(t1.BANDNR)) AS COUNT_of_BANDNR, 
            (SUM(t1.Betroffen_OS_Filet)) AS SUM_of_Betroffen_OS_Filet, 
            (SUM(t1.Betroffengr10_OS_Filet)) AS SUM_of_Betroffengr10_OS_Filet, 
            (SUM(t1.Betroffengr100_OS_Filet)) AS SUM_of_Betroffengr100_OS_Filet
      FROM PUBLIC.DB1 t1
      GROUP BY t1.Monat_BBS;
QUIT;

/************** AB HIER NOCHT NICHT KONVERTIERT **********/

/*
PROC SQL;
	CREATE VIEW work.SORTTempTableSorted AS
		SELECT T.SUM_of_Betroffengr100_OS_Filet, T.Monat_BBS, T.COUNT_of_BANDNR
	FROM work.QUERY1 as T;
QUIT;
*/

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 1*/
/*Shewhart X-S-CHART mit 3 SIGMA Level getrennt nach LEITGUETEBB - diese Trennung nach Leitgüte sollte interaktiv passieren mit den "Actions"*/
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* Columns processname and subgroupname partition the data for one control chart.*/
%delete_table(lib=public,ds=xschart_bsp1_outlimits);
%delete_table(lib=public,ds=xschart_bsp1_outtable);
proc spc data=public.db1 
	processname=ProcessName subgroupname=LEITGUETEBB subgroupvalue=Monat_BBS processvalue=ZUF_OS_FL_FILET ;
	xschart / 	exchart tests=1 to 8 tests2=1 to 8
				outlimits=public.xschart_bsp1_outlimits outtable=public.xschart_bsp1_outtable;
run;

/* Workaround: Subgroupname wird in 3.3. nicht in die Outputtablellen geschrieben */
data public.xschart_bsp1_outtable;
	set public.xschart_bsp1_outtable;
	id = _N_;
	if id < 7 then LEITGUETEBB='C974'; else LEITGUETEBB='XS7F';
run;

proc casutil;
	/*promote incaslib=public casdata="xschart_bsp1_outlimits";*/
	promote incaslib=public casdata="xschart_bsp1_outtable";
quit;

/*
PROC SQL;
	CREATE VIEW WORK.SORTTemp2 AS
		SELECT T.ZUF_OS_FL_FILET, T.Monat_BBS, T.LEITGUETEBB
	FROM WORK.DB1 as T ORDER BY T.LEITGUETEBB, T.Monat_BBS
;
QUIT;

TITLE;
TITLE1 "Shewhart-Analyse von: ZUF_OS_FL_FILET*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
PROC SHEWHART DATA = WORK.SORTTemp2
;
	XSCHART 	 (ZUF_OS_FL_FILET)	* Monat_BBS	/
	 OUTTABLE=WORK.SHEW_XSChart
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
	CFRAME=CXD3D3D3
;
	BY LEITGUETEBB;
	;
RUN; QUIT;
TITLE; FOOTNOTE;
*/


/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 a.*/
/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit SIGMAS=3
   ------------------------------------------------------------------- */
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

%_eg_conditional_dropds(WORK.SHEW_Pchart_mit3sigma);
	SYMBOL VALUE=PLUS;

PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.SUM_of_Betroffengr100_OS_Filet, T.Monat_BBS, T.COUNT_of_BANDNR
	FROM WORK.QUERY1 as T
;
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
	SUBGROUPN=COUNT_of_BANDNR
;
	;
RUN; QUIT;
TITLE; FOOTNOTE;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 b.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit SIGMAS=0.5
   ------------------------------------------------------------------- */
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

%_eg_conditional_dropds(WORK.SHEW_Pchart_mitsigma);
	SYMBOL VALUE=PLUS;

PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.SUM_of_Betroffengr100_OS_Filet, T.Monat_BBS, T.COUNT_of_BANDNR
	FROM WORK.QUERY1 as T
;
QUIT;
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
	COUT=RED
	COUTFILL=RED
	CFRAME=CXD3D3D3
	SUBGROUPN=COUNT_of_BANDNR
;
	;
RUN; QUIT;
TITLE; FOOTNOTE;

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 c.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit alpha=0.617 (Pendant zu sigmas=0.5) 
   ------------------------------------------------------------------- */
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

%_eg_conditional_dropds( WORK.SHEW_Pchart_mitalpha);

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
RUN; QUIT;
TITLE; FOOTNOTE;





/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Beispiel 2 d.*/

/* -------------------------------------------------------------------
PROC SHEWHART P-CHART mit alpha=0.617 (Pendant zu sigmas=0.5) und problimits=discrete
   ------------------------------------------------------------------- */
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

%_eg_conditional_dropds(WORK.SHEW_Pchart_mitalpha_discr);

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
RUN; QUIT;
TITLE; FOOTNOTE;

proc casutil;
	promote incaslib=casuser casdata="simulated_Row7000_Col1500";
quit;


cas mysess terminate;
