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

%delete_table(lib=public,ds=DB3);
PROC FEDSQL sessref=mysess;
	CREATE TABLE PUBLIC.DB3 AS 
		SELECT cat150 as ProcessName,
			cat1 as LEITGUETEBB,
			cat100 as BANDNR,
			abs(round(inf1)) as Monat_BBS,
			abs(inf2+noise2) as ZUF_OS_FL_FILET,
			abs(inf3+noise3)/1000 as Betroffengr100_OS_Filet,
			y_binary
		FROM public.simulated_row7000_col1500;
QUIT;

/*ods exclude all;*/
proc binning data=PUBLIC.simulated_row7000_col1500 /*method=tree(MINNBINS=5 MAXNBINS=10)*/ /*numbin=5*/ woe;
   input inf1-inf10 /*/numbin=4*/;
   target y_binary / event='1' level=nominal;
   output out=public.binning_woe /* COPYVARS=(inf1-inf10)*/;
	code file="/home/sasdemo/binning_score.sas";
run;
/*ods exclude none;*/

cas mysess terminate;