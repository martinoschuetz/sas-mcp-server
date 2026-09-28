libname mydata "/home/gersta/sasdata";

option set=GRIDHOST ="inthpa1.ger.sas.com";
option set=GRIDINSTALLLOC="/opt/sas/TKGrid_REP";

options mprint;

%let HPDM_NODES=3; 
%let HPDM_LASR=Y;
%let HPDM_GRID=ALWAYS;  

libname mylasr clear;
LIBNAME mylasr SASIOLA TAG=vagersta PORT=10121 SIGNER="inthpa1.ger.sas.com:7980/SASLASRAuthorization" HOST="inthpa1.ger.sas.com";

/* ------------------------------------------------------------------------- */
/* Initialize settings for Hadoop                                            */
/* ------------------------------------------------------------------------- */

%let SAS_HADOOP_JAR_PATH=/opt/sas/thirdparty/hadoop/lib;
%let SAS_HADOOP_CONFIG_PATH=/opt/sas/thirdparty/hadoop/conf;
%let SAS_HADOOP_CONFIG_XML=/opt/sas/thirdparty/hadoop/conf/hadoop-config.xml;
%let HIVESERVER=inthadoop1.ger.sas.com;
%let SCHEMA=germsz;
option sastrace=',,,d' sastraceloc=saslog nostsuffix;
option set=SAS_HADOOP_JAR_PATH="&SAS_HADOOP_JAR_PATH.";
option set=SAS_HADOOP_CONFIG_PATH="&SAS_HADOOP_CONFIG_PATH.";

/* Set up Hive data source */
libname myhive clear;
libname myhive HADOOP user="&SCHEMA." schema="&SCHEMA" subprotocol=hive2 server="&HIVESERVER." 
properties="hive.execution.engine=tez;hive.vectorized.execution.enabled=true;hive.vectorized.execution.reduce.enabled=true" 
DBCREATE_TABLE_OPTS="STORED AS ORC";


proc hpatest;
  performance nodes=all details
  gridhost='inthpa1.ger.sas.com' 
  installloc="/opt/sas/TKGrid";
run;

