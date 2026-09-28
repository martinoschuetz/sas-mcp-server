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
%let TKGRID_ROOT_HOSTNAME=inthpa1.ger.sas.com;
%let TKGRID_INSTALL_DIR=/opt/sas/TKGrid_REP;


/* ---------------------------------------------------- */
libname myhive hadoop subprotocol=hive2 port=&HIVE_SRV_PORT.
    host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.;

/* ---------------------------------------------------- */
data myhive.sascars;
    set sashelp.cars;
run;


/* ---------------------------------------------------- */
proc hpsummary data=myhive.sascars;
     performance host="&TKGRID_ROOT_HOSTNAME." install="&TKGRID_INSTALL_DIR." nodes=all details ;
     var invoice;
     output out=summary MIN= p1= p5= p10= p25= p50= p75= p90= p95= p99= MAX= / autoname;
run;
