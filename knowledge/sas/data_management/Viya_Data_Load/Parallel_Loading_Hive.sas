CAS mySession SESSOPTS=(messagelevel=all CASLIB=public TIMEOUT=999 LOCALE="en_US");
CASLIB _ALL_ ASSIGN;
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;

%macro libchk;
	%if %sysfunc(libref(cashive))=0 %then
		%do;
			caslib cashive clear;
		%end;
%mend;

%libchk;

/* Define the caslib for parallel execution */
caslib cashive datasource=(srctype="hadoop", server="sascdh01.race.sas.com", 
	username="&gateuserid", dataTransferMode="parallel", 
	hadoopconfigdir="/opt/MyHadoop/CDH/Config", 
	hadoopjarpath="/opt/MyHadoop/CDH/Jars", schema="cashive");

proc casutil;
	list files incaslib="cashive";
quit;

proc casutil;
	load casdata="baseball" incaslib="cashive" outcaslib="cashive" 
		casout="&gateuserid._baseball" replace;
run;

proc casutil;
	list tables incaslib="cashive";
quit;

proc casutil;
	droptable casdata="&gateuserid._baseball" quiet;
quit;

cas mySession terminate;

 

