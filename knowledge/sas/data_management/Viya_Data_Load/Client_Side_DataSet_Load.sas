CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* assign a BASE SAS libname */
libname indata "/home/&gateuserid./";

/* save .sas7bdat file under user’s home directory */
data indata.prdsale(replace=yes);
	set sashelp.prdsale;
run;

/* path type CASLIB, source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path;

*/
/* drop in-memory CAS table  */
proc casutil;
	droptable casdata="&gateuserid._DATA_prdsale" incaslib="DM" quiet;
quit;

	/* load SAS datasets from client machine to CAS */
	/* notice where clause, repeat, and compress statement during data load */
proc casutil;
	load data=indata.prdsale(where=(country="U.S.A.")) outcaslib="DM" 
		casout="&gateuserid._DATA_prdsale" repeat compress;
quit;

	/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
	list files  incaslib="DM";
quit;
	
CAS mySession TERMINATE;