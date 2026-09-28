*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
* 
*  Stored Process registriert durch 
*  Enterprise Guide Stored Process Manager V5.1.
*
*  ====================================================================
*  Stored Process-Name: Tierauswahl an JMP Pro
*  ====================================================================
*
*  Wörterbuch von Stored Process-Eingabeaufforderungen:
*  ____________________________________
*  TIERAUSWAHL
*       Typ: Text
*      Etikett: Tiere auswählen
*       Attr: Sichtbar
*    Standard: System.Collections.ArrayList
*  ____________________________________
*;


*ProcessBody;

%global TIERAUSWAHL;

%STPBEGIN;

OPTIONS VALIDVARNAME=ANY;

%macro ExtendValidMemName;

%if %sysevalf(&sysver>=9.3) %then options validmemname=extend;

%mend ExtendValidMemName;

%ExtendValidMemName;

%LET _SASSERVERNAME=%NRBQUOTE(SASApp);

;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);

/* --- Anfang der gemeinsam genutzten Makrofunktionen. --- */

/* Conditionally delete set of tables or views, if they exists          */
/* If the member does not exist, then no action is performed   */
%macro _eg_conditional_dropds /parmbuff;
   	%let num=1;
	/* flags to determine whether a PROC SQL step is needed */
	/* or even started yet                                  */
	%let stepneeded=0;
	%let stepstarted=0;
   	%let dsname=%scan(&syspbuff,&num,',()');
	%do %while(&dsname ne);	
		%if %sysfunc(exist(&dsname)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;
			%end;
				drop table &dsname;
		%end;
		%if %sysfunc(exist(&dsname,view)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;
			%end;
				drop view &dsname;
		%end;
		%let num=%eval(&num+1);
      	%let dsname=%scan(&syspbuff,&num,',()');
	%end;
	%if &stepstarted %then %do;
		quit;
	%end;
%mend _eg_conditional_dropds;

/* Build where clauses from stored process parameters */

%macro _eg_WhereParam( COLUMN, PARM, OPERATOR, TYPE=S, MATCHALL=_ALL_VALUES_, MATCHALL_CLAUSE=1, MAX= , IS_EXPLICIT=0);
  %local q1 q2 sq1 sq2;
  %local isEmpty;
  %local isEqual;
  %let isEqual = ("%QUPCASE(&OPERATOR)" = "EQ" OR "&OPERATOR" = "=");
  %let isNotEqual = ("%QUPCASE(&OPERATOR)" = "NE" OR "&OPERATOR" = "<>");
  %let isIn = ("%QUPCASE(&OPERATOR)" = "IN");
  %let isNotIn = ("%QUPCASE(&OPERATOR)" = "NOT IN");
  %local isString;
  %let isString = (%QUPCASE(&TYPE) eq S or %QUPCASE(&TYPE) eq STRING );
  %if &isString %then
  %do;
    %let q1=%str(%");
    %let q2=%str(%");
	%let sq1=%str(%'); 
    %let sq2=%str(%'); 
  %end;
  %else %if %QUPCASE(&TYPE) eq D or %QUPCASE(&TYPE) eq DATE %then 
  %do;
    %let q1=%str(%");
    %let q2=%str(%"d);
	%let sq1=%str(%'); 
    %let sq2=%str(%'); 
  %end;
  %else %if %QUPCASE(&TYPE) eq T or %QUPCASE(&TYPE) eq TIME %then
  %do;
    %let q1=%str(%");
    %let q2=%str(%"t);
	%let sq1=%str(%'); 
    %let sq2=%str(%'); 
  %end;
  %else %if %QUPCASE(&TYPE) eq DT or %QUPCASE(&TYPE) eq DATETIME %then
  %do;
    %let q1=%str(%");
    %let q2=%str(%"dt);
	%let sq1=%str(%'); 
    %let sq2=%str(%'); 
  %end;
  %else
  %do;
    %let q1=;
    %let q2=;
	%let sq1=;
    %let sq2=;
  %end;
  
  %if "&PARM" = "" %then %let PARM=&COLUMN;

  %local isBetween;
  %let isBetween = ("%QUPCASE(&OPERATOR)"="BETWEEN" or "%QUPCASE(&OPERATOR)"="NOT BETWEEN");

  %if "&MAX" = "" %then %do;
    %let MAX = &parm._MAX;
    %if &isBetween %then %let PARM = &parm._MIN;
  %end;

  %if not %symexist(&PARM) or (&isBetween and not %symexist(&MAX)) %then %do;
    %if &IS_EXPLICIT=0 %then %do;
		not &MATCHALL_CLAUSE
	%end;
	%else %do;
	    not 1=1
	%end;
  %end;
  %else %if "%qupcase(&&&PARM)" = "%qupcase(&MATCHALL)" %then %do;
    %if &IS_EXPLICIT=0 %then %do;
	    &MATCHALL_CLAUSE
	%end;
	%else %do;
	    1=1
	%end;	
  %end;
  %else %if (not %symexist(&PARM._count)) or &isBetween %then %do;
    %let isEmpty = ("&&&PARM" = "");
    %if (&isEqual AND &isEmpty AND &isString) %then
       &COLUMN is null;
    %else %if (&isNotEqual AND &isEmpty AND &isString) %then
       &COLUMN is not null;
    %else %do;
	   %if &IS_EXPLICIT=0 %then %do;
           &COLUMN &OPERATOR %unquote(&q1)&&&PARM%unquote(&q2)
	   %end;
	   %else %do;
	       &COLUMN &OPERATOR %unquote(%nrstr(&sq1))&&&PARM%unquote(%nrstr(&sq2))
	   %end;
       %if &isBetween %then 
          AND %unquote(&q1)&&&MAX%unquote(&q2);
    %end;
  %end;
  %else 
  %do;
	%local emptyList;
  	%let emptyList = %symexist(&PARM._count);
  	%if &emptyList %then %let emptyList = &&&PARM._count = 0;
	%if (&emptyList) %then
	%do;
		%if (&isNotin) %then
		   1;
		%else
			0;
	%end;
	%else %if (&&&PARM._count = 1) %then 
    %do;
      %let isEmpty = ("&&&PARM" = "");
      %if (&isIn AND &isEmpty AND &isString) %then
        &COLUMN is null;
      %else %if (&isNotin AND &isEmpty AND &isString) %then
        &COLUMN is not null;
      %else %do;
	    %if &IS_EXPLICIT=0 %then %do;
            &COLUMN &OPERATOR (%unquote(&q1)&&&PARM%unquote(&q2))
	    %end;
		%else %do;
		    &COLUMN &OPERATOR (%unquote(%nrstr(&sq1))&&&PARM%unquote(%nrstr(&sq2)))
		%end;
	  %end;
    %end;
    %else 
    %do;
       %local addIsNull addIsNotNull addComma;
       %let addIsNull = %eval(0);
       %let addIsNotNull = %eval(0);
       %let addComma = %eval(0);
       (&COLUMN &OPERATOR ( 
       %do i=1 %to &&&PARM._count; 
          %let isEmpty = ("&&&PARM&i" = "");
          %if (&isString AND &isEmpty AND (&isIn OR &isNotIn)) %then
          %do;
             %if (&isIn) %then %let addIsNull = 1;
             %else %let addIsNotNull = 1;
          %end;
          %else
          %do;		     
            %if &addComma %then %do;,%end;
			%if &IS_EXPLICIT=0 %then %do;
                %unquote(&q1)&&&PARM&i%unquote(&q2) 
			%end;
			%else %do;
			    %unquote(%nrstr(&sq1))&&&PARM&i%unquote(%nrstr(&sq2)) 
			%end;
            %let addComma = %eval(1);
          %end;
       %end;) 
       %if &addIsNull %then OR &COLUMN is null;
       %else %if &addIsNotNull %then AND &COLUMN is not null;
       %do;)
       %end;
    %end;
  %end;
%mend;
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
/* --- Ende der gemeinsam genutzten Makrofunktionen. --- */

/* --- Codeanfang für "Attribute generieren". --- */
%_eg_conditional_dropds(HIRSCHE.ALLE_TIERE_FINAL);

PROC SQL;
   CREATE TABLE HIRSCHE.ALLE_TIERE_FINAL AS 
   SELECT /* Kurzname */
            (SCANQ(tier, 3,'_')) LABEL="Kurzname" AS Kurzname, 
          t1.no LABEL="No" AS No, 
          /* Geschlecht */
            (SCANQ(tier, 1,'_')) LABEL="Geschlecht" AS Geschlecht, 
          /* Halsbandnummer */
            (SCANQ(tier, 2,'_')) LABEL="Halsbandnummer" AS Halsbandnummer, 
          /* Status */
            (SCANQ(tier, 4,'_')) LABEL="Status" AS Status, 
          /* LDT */
            (DHMS(datepart(lmt_date),hour(timepart(lmt_time)), minute(timepart(lmt_time)),second(timepart(lmt_time)))) 
            FORMAT=DATETIME18. LABEL="Local Date Time" AS LDT, 
          t1.ECEF_X, 
          t1.ECEF_Y, 
          t1.ECEF_Z, 
          t1.Latitude, 
          t1.Longitude, 
          t1.Height, 
          t1.Easting, 
          t1.Northing, 
          t1.Temp, 
          t1.DOP, 
          t1.Nav, 
          t1.Validated, 
          t1.Sats, 
          t1.Sat, 
          t1.'C/N'n LABEL="CN" AS CN, 
          t1.Main, 
          t1.Bkup, 
          t1.Remarks
      FROM HIRSCHE.ALLE_TIERE t1
      WHERE %_eg_WhereParam( (CALCULATED Kurzname), Tierauswahl, IN, TYPE=S, IS_EXPLICIT=0 )
      ORDER BY Kurzname,
               t1.no;
QUIT;
/* --- Ende des Codes für "Attribute generieren". --- */

/* --- Codeanfang für "Verteilungsanalyse". --- */
/* -------------------------------------------------------------------
   Von SAS-Anwendungsroutine generierter Code

   Generiert am: Dienstag, 8. Mai 2012 um 13:59:58
   Von Anwendungsroutine: Verteilungsanalyse

   Eingabedaten: SASApp:HIRSCHE.ALLE_TIERE_FINAL
   Server:  SASApp
   ------------------------------------------------------------------- */

%_eg_conditional_dropds(WORK.SORTTempTableSorted);
/* -------------------------------------------------------------------
   PROC SHEWHART unterstützt nicht DEVICE=ACTIVEX. Es wird zu PNG gewechselt.
   ------------------------------------------------------------------- */
OPTIONS DEV=PNG;
/* -------------------------------------------------------------------
   Datei SASApp:HIRSCHE.ALLE_TIERE_FINAL sortieren
   ------------------------------------------------------------------- */

PROC SQL;
	CREATE VIEW WORK.SORTTempTableSorted AS
		SELECT T.DOP, T.Sats, T.Sat, T.Main, T.Bkup
	FROM HIRSCHE.ALLE_TIERE_FINAL as T
;
QUIT;
TITLE;
TITLE1 "Verteilungsanalyse von: DOP, Sats, Sat, Main, Bkup";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
	ODS EXCLUDE EXTREMEOBS MODES MOMENTS QUANTILES;
	
	GOPTIONS htext=1 cells;
	SYMBOL v=SQUARE c=BLUE h=1 cells;
	PATTERN v=SOLID
	;
PROC UNIVARIATE DATA = WORK.SORTTempTableSorted
		CIBASIC(TYPE=TWOSIDED ALPHA=0.05)
		MU0=0
;
	VAR DOP Sats Sat Main Bkup;
	HISTOGRAM / 	CFRAME=GRAY CAXES=BLACK WAXIS=1  CBARLINE=BLACK CFILL=BLUE PFILL=SOLID ;
	 
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

/* --- Codeanfang für "Einfache Häufigkeiten". --- */
/* -------------------------------------------------------------------
   Von SAS-Anwendungsroutine generierter Code

   Generiert am: Dienstag, 8. Mai 2012 um 13:59:58
   Von Anwendungsroutine: Einfache Häufigkeiten

   Eingabedaten: SASApp:HIRSCHE.ALLE_TIERE_FINAL
   Server:  SASApp
   ------------------------------------------------------------------- */

%_eg_conditional_dropds(WORK.SORT);
/* -------------------------------------------------------------------
   Datei SASApp:HIRSCHE.ALLE_TIERE_FINAL sortieren
   ------------------------------------------------------------------- */

PROC SQL;
	CREATE VIEW WORK.SORT AS
		SELECT T.Nav, T.Validated
	FROM HIRSCHE.ALLE_TIERE_FINAL as T
;
QUIT;

TITLE;
TITLE1 "Einfache Häufigkeiten";
TITLE2 "Ergebnisse";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&_SASSERVERNAME, &SYSSCPL) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";
ODS GRAPHICS ON;
PROC FREQ DATA=WORK.SORT
	ORDER=INTERNAL
;
	TABLES Nav /  SCORES=TABLE plots(only)=freq;
	TABLES Validated /  SCORES=TABLE plots(only)=freq;
RUN;
ODS GRAPHICS OFF;
/* -------------------------------------------------------------------
   Ende Code der Anwendungsroutine.
   ------------------------------------------------------------------- */
RUN; QUIT;
%_eg_conditional_dropds(WORK.SORT);
TITLE; FOOTNOTE;

/* --- Ende des Codes für "Einfache Häufigkeiten". --- */

/* --- Codeanfang für "Tierauswahl an JMP Pro". --- */
libname jmppkg "&_STPWORK";
filename stpwork "&_STPWORK";


* This SAS code is used to return the jmp script from the stored process;
data _null_;
   file stpwork(Tabulierung.jsl) encoding="utf-16le" BOM;
*  Read JSL file from an embedded datalines4 section;  
   infile datalines4 length=len;
*  Set up a line variable that can contain 32K chars;  
   length line $32676;
*  Set up a continuedline variable that can contain 4000 chars;  
   length continuedline $4000;
*  Set up a one char cont (continuation) variable.
*  This will be used to determine if one of the embedded script
*  lines is a continuation of a previous line;
   length cont $1;
*  Start the input at the current file location.
*  This will set the 'len' variable to the lenght of the line to be read;
   input @;
*  Calculate the size of the JSL line (minus one for the continuation char);
   llen = len - 1;
*  Read the continuation character, then the JSL line;
   input @1 cont $1 @2 line $varying. llen;
*  If the '*' continuation character is found, then keep reading lines
*  until no more continuations around found.  Each continuation line 
*  will be appended to the current line (at least up to 32K chars)
*  lines are trimed, which theorically could cause a problem if a
*  continuation were encountered within a really long quoted 
*  whitespace, but since lines can be 4000 characters long this
*  is very unlikely.  Hopefully, ever JSL line will fit on 
*  one datalines4 line, without need of continuation;
   do while (cont = '*');
      input @1 cont $1 @2 continuedline $varying. llen;
      line = trim(line)||continuedline;
      end;
   line = trim(line);
*  Write the line into the output file (package);
   put line;
*  Start the dataline4 section
*  NOTE: Each line of the dataline4 section is formatted as follows:
*       Column 1: A one character continuation character.  If this character is
*                 '*' then this line is continued on the next line and the lines
*                 will be concatenated.  If it contains a character other than '*'
*                 it is assumed that the current line is not continued.  This
*                 might change in the future, if other uses are needed for this first
*                 column.  IN ALL CASES THE FIRST CHARACTER (COLUMN 1) IS DISCARDED.
*       Column 2-4001: The actual JSL script line
*  Why is this done?
*      In order to embed the JSL within the SAS language we must make sure that
*      the semantic nature of one doesn't interact with the other.  It would be 
*      'bad' if a line of semi-colon characters found in the middle of a JSL script 
*      were to be interpreted as a datalines4 termination.  By offseting the JSL 
*      script by one character (column) it is not possible for the contents of the 
*      JSL script to accidently terminate the datalines4 section.  This ensures that
*      the JSL script contents will not interact in an unintended way with the 
*      executing SAS code.  And also ensure that JSL with extremely long lines
*      will be handled in a reasonable and forgiving way;
   datalines4;
 Tabulate( Add Table( Row Table( Grouping Columns( :Kurzname, :Geschlecht ) ) ) );
;;;;
run;


proc copy in=HIRSCHE out=jmppkg;
   select ALLE_TIERE_FINAL;
run;
proc datasets nodetails nolist library=jmppkg;
   change ALLE_TIERE_FINAL=alle_tiere_final;
run; quit;

/* --- Ende des Codes für "Tierauswahl an JMP Pro". --- */

*  Anfang des EG-generierten Codes (diese Zeile nicht bearbeiten);
;*';*";*/;quit;
%STPEND;

*  Ende des EG-generierten Codes (diese Zeile nicht bearbeiten);

