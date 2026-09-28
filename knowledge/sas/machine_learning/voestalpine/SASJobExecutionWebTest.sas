options mprint;

/* start a CAS session and assign the libnames */
options cashost="&SYSHOSTNAME." casport=5570;
cas mysess sessopts=(timeout=1800 metrics=true);
caslib _all_ assign;

%macro delete_table(lib=,ds=);
	%if %sysfunc(exist(&lib..&ds.,DATA)) %then
		%do;
			proc casutil;
				droptable incaslib=&lib. casdata="&ds.";
			quit;
		%end;
%mend;

%global LEITGUETEBB_value;
%put &=LEITGUETEBB_value;

%global process_var;
%put &=process_var;

%global process_var_name;
%put &=process_var_name;

%delete_table(lib=public,ds=JobDB);

PROC FEDSQL sessref=mysess;
	CREATE TABLE PUBLIC.JobDB AS 
		SELECT 	'Process1' as ProcessName,
			cat1 as LEITGUETEBB,
			cat100 as BANDNR,
			abs(round(inf1)) as Monat_BBS,
			abs(%sysfunc(htmlencode(&process_var.))+noise2) as %sysfunc(htmlencode(&process_var_name.))
		FROM public.simulated_row7000_col1500
			HAVING cat1 = %sysfunc(htmlencode(&LEITGUETEBB_value.));
QUIT;

/* Classical QC approach requires sorting */
PROC SQL;
	CREATE VIEW WORK.SORTTemp2 AS
		SELECT T.&process_var_name., T.Monat_BBS, T.LEITGUETEBB, ProcessName
			FROM public.JobDB as T ORDER BY T.ProcessName, T.LEITGUETEBB, T.Monat_BBS;
QUIT;

TITLE;
TITLE1 "Shewhart-Analyse von: &process_var_name.*Monat_BBS";
FOOTNOTE;
FOOTNOTE1 "Erzeugt durch das SAS System (&SYSHOSTNAME., &SYSSCPL.) am %TRIM(%QSYSFUNC(DATE(), NLDATE20.)) um %TRIM(%SYSFUNC(TIME(), TIMEAMPM12.))";

PROC SHEWHART DATA = WORK.SORTTemp2;
	XSCHART 	 (&process_var_name.)	* Monat_BBS	/
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
RUN;

QUIT;

TITLE;
FOOTNOTE;

cas mysess terminate;