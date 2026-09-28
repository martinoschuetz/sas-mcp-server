CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* path type CASLIB, source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path;

*/
/* assign a BASE SAS libname */
libname indata "/home/&gateuserid./";

/* assign a CAS engine libname */
libname myCaslib cas caslib="DM";

/* save a .sas7bdat file under user’s home directory */
data indata.prdsale(replace=yes);
	set sashelp.prdsale;
run;

/* drop in-memory CAS table  */
proc casutil;
	droptable casdata="&gateuserid._prdsale_DS" incaslib="DM" quiet;
quit;

/* load SAS datasets from client machine to CAS */
data myCaslib.&gateuserid._prdsale_DS;
	set indata.prdsale;
run;

/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
	quit;
	
CAS mySession TERMINATE;