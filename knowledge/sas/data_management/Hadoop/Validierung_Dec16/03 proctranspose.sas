/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;
options dsaccel="any" ds2accel="any" SQLGENERATION=DBMS;

/* ---------------------------------------------------- */
%put ****    *** Checking if Hadoop environment variables have been set ***;
%put ****        OK ... SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put ****        OK ... SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);

%let HIVE_SRV_HOSTNAME=inthadoop1.ger.sas.com;
%let HIVE_SRV_PORT=10000;
%let HIVE_SCHEMA=sas_managed;
%let HIVE_TBL_OPTS=STORED AS ORC;
%let SAS_TESTUSER=gerhje;

/* ---------------------------------------------------- */
libname myhive hadoop subprotocol=hive2 port=&HIVE_SRV_PORT.
    host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.;

/* ------------------------------------------------------------------------- */
/* Spieldaten generieren */
data long1 ; 
  input famid year faminc ; 
cards ; 
1 96 40000 
1 97 40500 
1 98 41000 
2 96 45000 
2 97 45400 
2 98 45800 
3 96 75000 
3 97 76000 
3 98 77000 
4 96 85000 
4 97 86000 
4 98 77000 
; 
run;
 
data myhive.famine;
set work.long1;
run;
 
/* ------------------------------------------------------------------------- */
proc delete data=myhive.famine_transposed;run;
proc transpose data=myhive.famine out=myhive.famine_transposed prefix=faminc
       LET indb=yes;
    by famid ;
    id year;
    var faminc;
run;
 
/* ------------------------------------------------------------------------- */
proc print data=myhive.famine;
run;
proc print data=myhive.famine_transposed;
run;
