*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
*
*  Stored Process registriert durch
*  Enterprise Guide Stored Process Manager V6.1
*
*  ====================================================================
*  Stored Process-Name: WebServiceTest
*  ====================================================================
*;


*ProcessBody;

%STPBEGIN;

%LET _SASSERVERNAME=%NRBQUOTE(Unbekannt);

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);


/* --- Anfang der gemeinsam genutzten Makrofunktionen. --- */
/* save the current settings of XPIXELS and YPIXELS */
/* so that they can be restored later               */
%macro _sas_pushchartsize(new_xsize, new_ysize);
	%global _savedxpixels _savedypixels;
	options nonotes;
	proc sql noprint;
	select setting into :_savedxpixels
	from sashelp.vgopt
	where optname eq "XPIXELS";
	select setting into :_savedypixels
	from sashelp.vgopt
	where optname eq "YPIXELS";
	quit;
	options notes;
	GOPTIONS XPIXELS=&new_xsize YPIXELS=&new_ysize;
%mend;

/* restore the previous values for XPIXELS and YPIXELS */
%macro _sas_popchartsize;
	%if %symexist(_savedxpixels) %then %do;
		GOPTIONS XPIXELS=&_savedxpixels YPIXELS=&_savedypixels;
		%symdel _savedxpixels / nowarn;
		%symdel _savedypixels / nowarn;
	%end;
%mend;

/* Conditionally delete set of tables or views, if they exists          */
/* If the member does not exist, then no action is performed   */
%macro _eg_conditional_dropds /parmbuff;
	
   	%local num;
   	%local stepneeded;
   	%local stepstarted;
   	%local dsname;
	%local name;

   	%let num=1;
	/* flags to determine whether a PROC SQL step is needed */
	/* or even started yet                                  */
	%let stepneeded=0;
	%let stepstarted=0;
   	%let dsname= %qscan(&syspbuff,&num,',()');
	%do %while(&dsname ne);	
		%let name = %sysfunc(left(&dsname));
		%if %qsysfunc(exist(&name)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;

			%end;
				drop table &name;
		%end;

		%if %sysfunc(exist(&name,view)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;
			%end;
				drop view &name;
		%end;
		%let num=%eval(&num+1);
      	%let dsname=%qscan(&syspbuff,&num,',()');
	%end;
	%if &stepstarted %then %do;
		quit;
	%end;
%mend _eg_conditional_dropds;
/* --- Ende der gemeinsam genutzten Makrofunktionen. --- */

/* --- Codeanfang für "Verteilungsanalyse". --- */
/* -------------------------------------------------------------------
   Von SAS-Anwendungsroutine generierter Code

   Generiert am: Dienstag, 29. April 2014 um 15:29:47
   Von Anwendungsroutine: Verteilungsanalyse

   Eingabedaten: SASApp:SASHELP.ORSALES
   Server:  SASApp
   ------------------------------------------------------------------- */

%_eg_conditional_dropds(WORK.SORTTempTableSorted);
/* -------------------------------------------------------------------
   PROC SHEWHART unterstützt nicht DEVICE=ACTIVEX. Es wird zu PNG gewechselt.
   ------------------------------------------------------------------- */
OPTIONS DEV=PNG;
/* -------------------------------------------------------------------
   Datei SASHELP.ORSALES sortieren
   ------------------------------------------------------------------- */
PROC SORT
	DATA=SASHELP.ORSALES(KEEP=Profit Product_Group)
	OUT=WORK.SORTTempTableSorted
	;
	BY Product_Group;
RUN;
TITLE;
TITLE1 "Verteilungsanalyse von: Profit";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
	ODS EXCLUDE EXTREMEOBS MODES MOMENTS QUANTILES;
PROC UNIVARIATE DATA = WORK.SORTTempTableSorted
		CIBASIC(TYPE=TWOSIDED ALPHA=0.05)
		MU0=0
;
	BY Product_Group;
	VAR Profit;
	HISTOGRAM / NOPLOT ;
/* -------------------------------------------------------------------
   Ende Code der Anwendungsroutine.
   ------------------------------------------------------------------- */
RUN; QUIT;
%_eg_conditional_dropds(WORK.SORTTempTableSorted);
TITLE; FOOTNOTE;
/* -------------------------------------------------------------------
   Ursprüngliche Einstellung des Gerätetyps wird wiederhergestellt.
   ------------------------------------------------------------------- */
OPTIONS DEV=ACTIVEX;

/* --- Ende des Codes für "Verteilungsanalyse". --- */

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
;*';*";*/;quit;
%STPEND;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);

