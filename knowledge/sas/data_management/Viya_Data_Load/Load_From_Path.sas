CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* CASLIB Path data source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path;

*/
/* List available source files/tables which can be loaded to CAS */
proc casutil;
	list files incaslib="DM";
	quit;

	/* Drop in-memory CAS table  */
proc casutil;
	droptable casdata="&gateuserid._SRL_prdsale" incaslib="DM" quiet;
	quit;

	/* load SAS datasets from path caslib DM to CAS */
proc casutil;
	load casdata="prdsale.sas7bdat" incaslib="DM" outcaslib="DM" 
		casout="&gateuserid._SRL_prdsale" promote;
	quit;

	/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
	quit;
	
CAS mySession TERMINATE;