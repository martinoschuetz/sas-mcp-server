/*
	Du musst unbedingt aufpassen, dass Du den „richtigen“ LASR Server erwischst bzw. das richtige TKGrid.
	Ich habe mir z.B. 2 LASR Server angelegt: einer zeigt nach /opt/sas/TKGrid, der andere verwendet /opt/sas/TKGrid_REP.
	Alles was über den EP von der INTHADOOP geladen werden soll (ob HPA oder LASR), muss über das TKGrid_REP laufen.
	Das sind meine Testcodes: ich kopiere eine Hive Tabelle über die HPDS2 nach WORK und nutze die HPSUMMARY 2x auf Hive Tabellen in unterschiedlichen Storage Formaten. 
	Im letzten Fall nutze ich den EP, um Daten aus Hive in meinen „TKGrid_REP“ LASR Server zu laden. Noch eins wg. dem LASR Load: ich glaube, die Hadoop Library muss so heissen wie das LASR Tag (in meinem Fall varepmsz).
*/

/* --------------------------------------------------------------------------- */
/* HPA Testing on Hive Tables                                                  */
/* --------------------------------------------------------------------------- */
LIBNAME varepmsz clear;
LIBNAME varepmsz HADOOP PORT=10000 SERVER="inthadoop1.ger.sas.com"
     SCHEMA=germsz USER=germsz;
proc hpds2 data=varepmsz.cars out=work.cars_ep;
     performance host="inthpa1.ger.sas.com" install="/opt/sas/TKGrid_REP" nodes=all details ;
     data DS2GTF.out;
          method run();
              set DS2GTF.in;
          end;
     enddata;
run;
proc hpsummary data=varepmsz.cars;
     performance host="inthpa1.ger.sas.com" install="/opt/sas/TKGrid_REP" nodes=all details ;
     var invoice;
     output out=summary MIN= p1= p5= p10= p25= p50= p75= p90= p95= p99= MAX= / autoname;
run;

/*
LIBNAME myorc HADOOP  PORT=10000 SERVER="&HIVESERVER."  
     SCHEMA=&USER. USER=&USER. DBCREATE_TABLE_OPTS="STORED AS ORC";
data myorc.cars_orc;
     set sashelp.cars;
run;
LIBNAME myorc clear;
*/

proc hpsummary data=varepmsz.cars_orc;
     performance host="inthpa1.ger.sas.com" install="/opt/sas/TKGrid_REP" nodes=all details ;
     var invoice;
     output out=summary MIN= p1= p5= p10= p25= p50= p75= p90= p95= p99= MAX= / autoname;
run;


/* Optimized Load via EP With PROC LASR */ 
proc lasr port=10210 verbose data=varepmsz.BAYAREA_ABT
     signer="inthpa1.ger.sas.com:7980/SASLASRAuthorization" add noclass;
     performance nodes=all host="inthpa1.ger.sas.com" details;
run;
