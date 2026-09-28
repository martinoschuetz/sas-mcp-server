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

libname mybase "/opt/sas/sashome/SASFoundation/9.4/samples/hps";

proc hadoop verbose;
     hdfs mkdir="/user/&SAS_TESTUSER./sasmodels";
     hdfs mkdir="/user/&SAS_TESTUSER./sashdmd";
     hdfs mkdir="/user/&SAS_TESTUSER./sashdmd/data";
     hdfs mkdir="/user/&SAS_TESTUSER./sashdmd/meta";
run;

data myhive.hmeq;
	set mybase.hmeq;
run;


/* ---------------------------------------------------- */
%let HCP=%sysget(SAS_HADOOP_CONFIG_PATH);
%LET INDCONN=%str(hadoop_cfg=&HCP.);

%indhd_publish_model(
    dir=/hadoop/exchange/dump/indb_scoring
	, datastep=score.sas 
	, xml=score.xml 
	, modeldir=/user/&SAS_TESTUSER./sasmodels
	, modelname=SCORE_HMEQ
	, action=replace 
	, trace=yes
);

%indhd_run_model( 
	inputtable=myhive.hmeq
	, outdatadir=/user/&SAS_TESTUSER./sashdmd/data/hmeq_scored
	, outmetadir=/user/&SAS_TESTUSER./sashdmd/meta/hmeq_scored.sashdmd
	, scorepgm=  /user/&SAS_TESTUSER./sasmodels/SCORE_HMEQ/SCORE_HMEQ.ds2 
	, forceoverwrite=false 
	, showproc=yes
	, trace=yes
); 

/* ---------------------------------------------------- */
libname myhdmd HADOOP server="&HIVE_SRV_HOSTNAME."
     HDFS_PERMDIR="/user/&SAS_TESTUSER./sashdmd/data"
     HDFS_METADIR="/user/&SAS_TESTUSER./sashdmd/meta";

proc print data=myhdmd.hmeq_scored(obs=10); 
run;

proc delete data=myhdmd.hmeq_scored;
run;