CAS mySession SESSOPTS=(messagelevel=all CASLIB=public TIMEOUT=999 
	LOCALE="en_US" metrics=true);
CASLIB _ALL_ ASSIGN;
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

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
	load data=sashelp.pricedata outcaslib="cashive" 
		casout="&gateuserid._pricedataCAS" replace;
run;

proc casutil;
	list tables incaslib="cashive";
quit;


proc casutil;
	save casdata="&gateuserid._pricedataCAS" casout="&gateuserid._pricedata" replace;
	list files;
quit;

proc casutil;
	droptable casdata="&gateuserid._pricedataCAS" quiet;
	deletesource casdata="&gateuserid._pricedata" quiet;
quit;

cas mySession terminate;



