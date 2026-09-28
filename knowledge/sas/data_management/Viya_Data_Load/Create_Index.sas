CAS mySession SESSOPTS=(CASLIB=casuser TIMEOUT=99 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* path type CASLIB, source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path global ;

*/
/* load SAS datasets from path caslib to CAS */
Proc cas;
	session mySession;
	table.loadtable / path="dm_fact_mega_corp.sas7bdat" Caslib="DM" 
		casout={name="&gateuserid._megacorp" caslib="DM" replace=True};
	run;
quit;

/* Create new indexed CAS table from existing CAS  table */
Proc cas;
	session mySession;
	table.index / table={name="&gateuserid._megacorp" Caslib="DM"} 
		casout={caslib="DM" name="&gateuserid._megacorpInd" IndexVars={"Date"} 
		replace=True};
	run;
quit;

/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
quit;

	/* to view CAS table columns level detail information */
Proc CAS;
	session mySession;
	setsessopt / caslib="DM";
	table.columninfo / table="&gateuserid._megacorpInd";
	run;
quit;

/* to view CAS table summary information */
Proc CAS;
	session mySession;
	setsessopt / caslib="DM";
	table.tabledetails / name="&gateuserid._megacorpInd" level="sum";
	run;
quit;

/* assign a CAS engine libname */
libname myCaslib cas caslib="DM";

/* executing PROC against non-indexed CAS table  */
PROC MDSUMMARY DATA=myCaslib.&gateuserid._megacorp;
	WHERE date between '01Jan2009'd and '31dec2009'd;
	output out=myCaslib.&gateuserid._mdsum;
run;

/* executing PROC against indexed CAS table */
PROC MDSUMMARY DATA=myCaslib.&gateuserid._megacorpInd;
	WHERE date between '01Jan2009'd and '31dec2009'd;
	output out=myCaslib.&gateuserid._mdsumInd;
run;

CAS mySession TERMINATE;