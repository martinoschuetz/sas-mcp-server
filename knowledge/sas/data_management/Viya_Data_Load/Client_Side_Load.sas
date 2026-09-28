CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* save a csv file under user’s home directory */
proc export data=sashelp.prdsale outfile="/home/&gateuserid/prdsale.csv" 
		REPLACE dbms=dlm;
	putnames=yes;
	delimiter=',';
run;

/* path type CASLIB, source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path;

*/
/* Drop in-memory CAS table  */
proc casutil;
	droptable casdata="&gateuserid._CSV_prdsale" incaslib="DM" quiet;
quit;

	/* load csv datasets from client machine to CAS */
proc casutil;
	load file="/home/&gateuserid./prdsale.csv" outcaslib="DM" 
		casout="&gateuserid._CSV_prdsale" copies=0 promote;
quit;

	/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
quit;

CAS mySession TERMINATE;