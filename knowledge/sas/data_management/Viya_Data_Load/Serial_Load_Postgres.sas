CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* Clear CASLIB if existed */
CASLIB _ALL_ ASSIGN;

%macro libchk;
	%if %sysfunc(libref(caspgdvd))=0 %then
		%do;
			caslib caspgdvd clear;
		%end;
%mend;

%libchk;

/* Create session scoped CASLIB  */
caslib caspgdvd datasource=(srctype="postgres", username="casdm", 
	password="saswin", server="sasdb.race.sas.com", database="dvdrental", 
	schema="public");

/* List available source files/tables which can be loaded to CAS */
proc casutil;
	list files incaslib="caspgdvd";
	quit;

	/* Drop in-memory CAS table */
proc casutil;
	droptable casdata="&gateuserid._SRLPG_film" incaslib="caspgdvd" quiet;
	quit;

	/* load a PGSQL table to CAS */
proc casutil;
	load casdata="film" incaslib="caspgdvd" casout="&gateuserid._SRLPG_film" 
		outcaslib="caspgdvd";
	quit;

	/* list in-memory table from CASLIB caspgdvd  */
proc casutil;
	list tables incaslib="caspgdvd";
	quit;
CAS mySession TERMINATE;