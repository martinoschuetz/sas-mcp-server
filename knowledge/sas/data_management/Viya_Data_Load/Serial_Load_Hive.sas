CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* Clear CASLIB hivelib if existed */
CASLIB _ALL_ ASSIGN;

%macro libchk;
	%if %sysfunc(libref(hivelib))=0 %then
		%do;
			caslib hivelib clear;
		%end;
%mend;

%libchk;

/* Create session scoped CASLIB hivelib */
caslib hivelib desc="HIVE Caslib" datasource=(SRCTYPE="hadoop", 
	SERVER="sascdh01.race.sas.com", dataTransferMode="serial", 
	username=&gateuserid., HADOOPCONFIGDIR="/opt/MyHadoop/CDH/Config/", 
	HADOOPJARPATH="/opt/MyHadoop/CDH/Jars/", schema="cashive", dfDebug=sqlinfo);

/* List available source files/tables which can be loaded to CAS */
proc casutil;
	list files incaslib="hivelib";
	quit;

	/* Drop in-memory CAS table */
proc casutil;
	droptable casdata="&gateuserid._SRLHV_prdsale" incaslib="hivelib" quiet;
	quit;

	/* load a Hive table to CAS */
proc casutil;
	load casdata="prdsale" incaslib="hivelib" casout="&gateuserid._SRLHV_prdsale" 
		outcaslib="hivelib" options={where="country='U.S.A' OR division='CONSUMER'"};
	quit;

	/* list in-memory table from CASLIB hivelib  */
proc casutil;
	list tables incaslib="hivelib";
	quit;

CAS mySession TERMINATE;