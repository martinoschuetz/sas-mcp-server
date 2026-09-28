option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;
options dsaccel="any" ds2accel="any" SQLGENERATION=DBMS;

libname myva clear;
LIBNAME myva SASIOLA  TAG=hvgerhje PORT=10111
     SIGNER="http://inthpa1.ger.sas.com:7980/SASLASRAuthorization"  
     HOST="inthpa1.ger.sas.com";

option set=GRIDHOST="inthpa1.ger.sas.com";
OPTION set=GRIDMODE="ASYM";
option set=GRIDINSTALLLOC="/opt/sas/TKGrid_REP";

proc delete data=myva.class2; run;
proc hpds2 data=sashelp.class out=myva.class2;
     performance host="inthpa1.ger.sas.com" 
		install="/opt/sas/TKGrid_REP" nodes=all details;
     data DS2GTF.out;
         method run();
              set DS2GTF.in;
         end;
     enddata;
run;

proc imstat;
	serverinfo / host="inthpa1.ger.sas.com" port=10111;
	tableinfo / host="inthpa1.ger.sas.com" port=10111;
run;quit;


