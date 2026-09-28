CAS mySession SESSOPTS=(messagelevel=all CASLIB=public TIMEOUT=999 
	LOCALE="en_US" metrics=true);
CASLIB _ALL_ ASSIGN;
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

%macro libchk;
	%if %sysfunc(libref(caspg))=0 %then
		%do;
			caslib caspg clear;
		%end;
%mend;

%libchk;

caslib caspg datasource=(srctype="postgres", username="casdm", 
	password="saswin", server="sasdb.race.sas.com", database="casdm", 
	schema="public", numreadnodes=10, numwritenodes=10);

proc casutil;
	droptable casdata="&gateuserid._airlineCAS" quiet;
	load data=sashelp.airline casout="&gateuserid._airlineCAS";
	list tables;
quit;

/* Perform a multi-node save from our PG table */
proc casutil;
	save casdata="&gateuserid._airlineCAS" casout="&gateuserid._airline" replace;
	list files;
quit;

proc casutil;
	droptable casdata="&gateuserid._airlineCAS" quiet;
	deletesource casdata="&gateuserid._airline" quiet;
quit;

cas mySession terminate;


