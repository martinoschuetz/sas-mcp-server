/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;

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

libname myhvex hadoop subprotocol=hive2 port=&HIVE_SRV_PORT.
    host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.
    DBCREATE_TABLE_OPTS="&HIVE_TBL_OPTS.";

/* ---------------------------------------------------- */
proc delete data=myhive.sascars; run;
proc delete data=myhive.sasprdsal2; run;
proc delete data=myhive.sascars2; run;
proc delete data=myhive.sasprdsal2_aggr; run;
proc delete data=myhive.sasprdsal2_nontxt; run;

data myhive.sascars;
    set sashelp.cars;
run;
proc sql;
        create table myhive.sasprdsal2 as
                select * From sashelp.prdsal2;
quit;

/* ---------------------------------------------------- */
proc sql;
    create table myhive.sascars2 as
      select count(*), make from myhive.sascars
      group by make;
quit;

proc sql;
    connect to hadoop(subprotocol=hive2 port=&HIVE_SRV_PORT.
            host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.);
    
    execute(
            create table &HIVE_SCHEMA..sasprdsal2_aggr as
                    select max(actual) as actual, country, prodtype, product, year
                            from &HIVE_SCHEMA..sasprdsal2
                            group by country, prodtype, product, year
    ) by hadoop;
    
    disconnect from hadoop;
quit;


/* ---------------------------------------------------- */
proc sql;
        create table myhvex.sasprdsal2_nontxt as
                select * from sashelp.prdsal2
                where state="New York";
quit;

proc sql;
        create table prd2 as
                select count(*), state from myhvex.sasprdsal2_nontxt
                group by state;
quit;


/* ---------------------------------------------------- */
proc summary data=myhive.sasprdsal2;
     var actual;
     output out=summary MIN= MAX= N= / autoname;
run;
