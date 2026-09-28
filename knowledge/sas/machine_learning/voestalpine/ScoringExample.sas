/* start a CAS session and assign the libnames */
options cashost="172.28.235.22" casport=5570;

cas mysess;
caslib _all_ assign;

/*
	To determine the name of the ASTORE for the CASDATA=parameter, open the dmcas_epscorecode.sas,
	downloaded from the pipline comparison in Model Studio. 
	In the top comments section, you should see a name ending with _ast.
	This is the ASTORE filename.
	If you see multiple entries take the last entry.
	Because Linux is case  sensitive, you will need to convert any letters in the filename to uppercase.
	Use PROC ASTORE to run the EP score code against the data.
*/
%let RSTORE=%upcase(_5pgxe32jycfq0o0qwl0bihpz1);
proc casutil;
	load casdata="&RSTORE._ast.sashdat" inCASlib="models" casOut="AStoreCAStable" outCASlib=casuser replace;
quit;

/* Investigate ASTORE structure */
proc astore;
	describe rstore=casuser.AStoreCAStable epcode="/home/sasdemo/SAS/dmcas_epscorecode.sas";
run;

/* Score using the ASTORE */
proc astore;
	score data=public.HMEQ_GERMSZ rstore=casuser.AStoreCAStable 
	epcode="/home/sasdemo/SAS/dmcas_epscorecode.sas" out=public.HMEQ_GERMSZ_scored;
quit;

cas mysess terminate;