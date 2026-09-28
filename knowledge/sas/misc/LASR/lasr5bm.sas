


        /*------------------------------------------------------------*/
        /*-- these describe the HPA and VA cluster                  --*/
        /*-- in this case the 140 r&d bigmath grid                  --*/
        /*------------------------------------------------------------*/

option set=GRIDHOST="bigmath.unx.sas.com";
option set=GRIDINSTALLLOC="/opt/v940/laxno/TKGrid_REP";
option set=GRIDMODE="ASYM";

option sql_ip_trace=(all);



        /*------------------------------------------------------------*/
        /*-- these are the 4 asymetric libname statements pointing  --*/
        /*-- to datasources that are not on the cluster, but are on --*/
        /*-- different database and hadoop appliances in the        --*/
        /*-- datacenter..                                           --*/
        /*------------------------------------------------------------*/

libname orasym oracle user=kent password=kent path='//ed01-scan.unx.sas.com:1521/exadat' schema=hps
   preserve_tab_names=no preserve_col_names=yes;
      
libname gpasym greenplm server="wintergreen.unx.sas.com" user=sasjwm password=sasjwm schema=public database=hps
  preserve_tab_names=yes preserve_col_names=yes;

libname tdasym teradata server="tera2650.unx.sas.com" user=kent password=kent database=HPS;  

options set=SAS_HADOOP_JAR_PATH="/u/kent/jars/cdh4/";
libname hdasym hadoop 
                         server="exa.unx.sas.com"
                         HDFS_TEMPDIR="/user/kent/temp"
                         HDFS_PERMDIR="/user/kent/anyfile"
                         HDFS_METADIR="/user/kent/anyfile"
                         DBCREATE_TABLE_EXTERNAL=NO
                         config="/u/kent/jars/exa.cfg";



        /*------------------------------------------------------------*/
        /*--  this is the local hadoop system on the same cluster,  --*/
        /*-- so is the only truly symmetric "same host" scenario in --*/
        /*-- the example.                                           --*/
        /*------------------------------------------------------------*/

libname hdlocl sashdat path="/user/kent";




        /*------------------------------------------------------------*/
        /*-- OK, go make a dataset in each of these libraries...    --*/
        /*------------------------------------------------------------*/
        
proc delete data=orasym.pk_orasym; run;
data orasym.pk_orasym; from='OracleAsym';    do i=1 to 100000; c=mod(i,7); u=uniform(123); output; end; run;

proc delete data=gpasym.pk_gpasym; run;
data gpasym.pk_gpasym; from='GreenPlumAsym'; do i=1 to 10000 ; c=mod(i,7); u=uniform(123); output; end; run;

proc delete data=tdasym.pk_tdasym; run;
data tdasym.pk_tdasym; from='TeradataAsym';  do i=1 to 100000; c=mod(i,7); u=uniform(123); output; end; run;

proc delete data=hdasym.pk_hdasym; run;
data hdasym.pk_hdasym; from='HadoopAsym';    do i=1 to 100000; c=mod(i,7); u=uniform(123); output; end; run;

proc delete data=hdlocl.pk_hdlocl; run;
data hdlocl.pk_hdlocl; from='Hadoop';        do i=1 to 100000; c=mod(i,7); u=uniform(123); output; end; run;




        /*------------------------------------------------------------*/
        /*-- now load the 5 datasets into one LASR server           --*/
        /*------------------------------------------------------------*/
        

proc lasr CREATE port=17284 path="/tmp/";
  performance nodes=all;
  run;


        /*------------------------------------------------------------*/
        /*-- now go assign lasr libnames, and do some IMSTAT lasr   --*/
        /*-- actions on these tables that have been loaded into the --*/
        /*-- LASR server..                                          --*/
        /*------------------------------------------------------------*/

libname lasr1  sasiola  port=17284 tag=orasym;
libname lasr2  sasiola  port=17284 tag=gpasym;
libname lasr3  sasiola  port=17284 tag=tdasym;
libname lasr4  sasiola  port=17284 tag=hdasym;
libname lasr5  sasiola  port=17284 tag="USER.KENT";



proc hpds2 in=orasym.pk_orasym out=lasr1.pk_orasym; data ds2gtf.out; method run(); set ds2gtf.in; output ds2gtf.out; end; enddata; run;
proc hpds2 in=gpasym.pk_gpasym out=lasr2.pk_gpasym; data ds2gtf.out; method run(); set ds2gtf.in; output ds2gtf.out; end; enddata; run;
proc hpds2 in=tdasym.pk_tdasym out=lasr3.pk_tdasym; data ds2gtf.out; method run(); set ds2gtf.in; output ds2gtf.out; end; enddata; run;
proc hpds2 in=hdasym.pk_hdasym out=lasr4.pk_hdasym; data ds2gtf.out; method run(); set ds2gtf.in; output ds2gtf.out; end; enddata; run;
proc hpds2 in=hdlocl.pk_hdlocl out=lasr5.pk_hdlocl; data ds2gtf.out; method run(); set ds2gtf.in; output ds2gtf.out; end; enddata; run;



        /*------------------------------------------------------------*/
        /*-- OK.  the tables are loaded into LASR.  to be sure lets --*/
        /*-- delete them from the DBMS appliances, clear their      --*/
        /*-- libnames...                                            --*/
        /*------------------------------------------------------------*/
        

proc delete data=orasym.pk_orasym; run;
proc delete data=gpasym.pk_gpasym; run;
proc delete data=tdasym.pk_tdasym; run;
proc delete data=hdasym.pk_hdasym; run;
proc delete data=hdlocl.pk_hdlocl; run;

libname orasym clear;
libname gpasym clear;
libname tdasym clear;
libname hdasym clear;
libname hdlocl clear;




proc imstat;

  tableinfo;
  run;
  
  table lasr1.pk_orasym;
  columnInfo;
  mdsummary u / groupby=from;
  mdsummary u / groupby=(from c);
  run;

  table lasr2.pk_gpasym;
  columnInfo;
  mdsummary u / groupby=from;
  mdsummary u / groupby=(from c);
  run;

  table lasr3.pk_tdasym;
  columnInfo;
  mdsummary u / groupby=from;
  mdsummary u / groupby=(from c);
  run;

  table lasr4.pk_hdasym;
  columnInfo;
  mdsummary u / groupby=from;
  mdsummary u / groupby=(from c);
  run;

  table lasr5.pk_hdlocl;
  columnInfo;
  mdsummary u / groupby=from;
  mdsummary u / groupby=(from c);
  run;




proc lasr STOP port=17284;   run;












