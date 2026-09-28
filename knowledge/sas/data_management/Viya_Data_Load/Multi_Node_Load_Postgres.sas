%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;
/*option DBIDIRECTEXEC=on;*/
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;

/* Create Postgres table for multi-node load */
/* We need to create our table this way to ensure we get the data types we want */
proc sql;
	connect to postgres as PG
   (user="casdm" password="saswin" server="sasdb.race.sas.com" 
		database="casdm");
	execute 
  (DROP TABLE IF EXISTS &gateuserid._SHOES) by PG;
	execute 
  (CREATE TABLE &gateuserid._SHOES(Inventory INT , Product TEXT , Region 
		TEXT) ) by PG;
quit;

/* Insert rows into the Postgres table */
%macro libchk;
	%if %sysfunc(libref(PG))=0 %then
		%do;
			libname PG clear;
		%end;
%mend;

%libchk;
libname PG postgres user="casdm" password="saswin" server="sasdb.race.sas.com" 
	database="casdm" schema="public";

Proc SQL;
	insert into PG.&gateuserid._SHOES select inventory, product, region from 
		sashelp.shoes;
quit;

proc datasets lib=pg; run;

/* Perform a multi-node load from our PG table */
/* Set the numreadnodes parameter high so the log tells us CAS is attempting multi-node load*/
CAS mySession SESSOPTS=(messagelevel=all CASLIB=public TIMEOUT=999 
	LOCALE="en_US" metrics=true);
CASLIB _ALL_ ASSIGN;

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
	droptable casdata="&gateuserid._shoesCAS" quiet;
	load casdata="&gateuserid._shoes" casout="&gateuserid._shoesCAS";
	list tables;
	quit;
	
proc casutil;
	droptable casdata="&gateuserid._shoesCAS" quiet;
	deletesource casdata="&gateuserid._shoes" quiet;
quit;

cas mySession terminate;

 

