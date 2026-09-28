
/* --------------------------------------------------------------------------- */
/* Remote parallel load to VA, HPA Testing */
/* --------------------------------------------------------------------------- */

proc lasr create PORT=&LASRPORT. path="/opt/sas/lasrsig" tablemem=80
     signer="http://&LASRHOST.:7980/SASLASRAuthorization";
     performance host="&LASRHOST." install="/opt/sas/TKGrid_REP" nodes=all;
run;

LIBNAME myhive HADOOP  PORT=10000 SERVER="&HIVESERVER."  
     SCHEMA=&USER. USER=&USER.;

LIBNAME vagerhje SASIOLA  TAG=vagerhje  PORT=&LASRPORT. 
     SIGNER="http://&LASRHOST.:7980/SASLASRAuthorization"  
     HOST="&LASRHOST.";

proc delete data=vagerhje.cars_ep; run;
proc hpds2 data=myhive.cars out=vagerhje.cars_ep;
     performance host="&LASRHOST." install="/opt/sas/TKGrid_REP" nodes=all details ;
     data DS2GTF.out;
          method run();
              set DS2GTF.in;
          end;
     enddata;
run;

proc imstat;
     serverinfo / host="&LASRHOST." port=&LASRPORT.;
     tableinfo  / host="&LASRHOST." port=&LASRPORT.;
run;quit;

proc lasr stop PORT=&LASRPORT.;
     performance host="&LASRHOST.";
run;


proc hpsummary data=myhive.cars;
     performance host="&LASRHOST." install="/opt/sas/TKGrid_REP" nodes=all details ;
     var invoice;
     class make;
     types () make;
     output out=summary;
run;
proc print data=summary(obs=10); run;

