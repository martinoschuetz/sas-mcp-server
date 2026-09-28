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
libname myhvex hadoop subprotocol=hive2 port=&HIVE_SRV_PORT.
    host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.
    DBCREATE_TABLE_OPTS="&HIVE_TBL_OPTS.";

/* ---------------------------------------------------- */
proc delete data=myhvex.sascars_orc; run;
proc delete data=myhvex.sascars_orc_ep; run;


/* ---------------------------------------------------- */
data myhvex.sascars_orc;
    set sashelp.cars;
run;


/* ---------------------------------------------------- */
proc ds2 indb=yes;

     thread compute / overwrite=yes;
          dcl int flag_audi;

          method run();
              set myhvex.sascars_orc;
              if make='Audi' then flag_audi=1;
              else flag_audi=0;
          end;
     endthread;

     data myhvex.sascars_orc_ep;
          dcl thread compute t;
          method run();
              set from t;
          end;
     enddata;

run; quit;


/* ---------------------------------------------------- */
%put ****    *** Cleanup (removing generated tables from &HIVE_SCHEMA.) ***;
proc delete data=myhive.sascars_orc; run;
proc delete data=myhive.sascars_orc_ep; run;

libname myhvex clear;
