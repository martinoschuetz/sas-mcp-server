/* --------------------------------------------------------------------- */ 
/* GLOBAL OPTIONS */ 
/* --------------------------------------------------------------------- */ 
%let SAS_HADOOP_JAR_PATH= C:\Sonst\Hadoop\inthadoop\hdp21_jars; 
%let SAS_HADOOP_CONFIG_PATH= C:\Sonst\Hadoop\inthadoop\xml; 
%let SAS_HADOOP_CONFIG_XML= C:\Sonst\Hadoop\inthadoop\xml_concat\hadoop-config.xml;
/* --------------------------------------------------------------------- */ 
%let HIVESERVER=inthadoop1.ger.sas.com;
/* --------------------------------------------------------------------- */ 
option set=SAS_HADOOP_JAR_PATH="&SAS_HADOOP_JAR_PATH."; 
option set=SAS_HADOOP_CONFIG_PATH="&SAS_HADOOP_CONFIG_PATH.";
option sastrace=',,,d' sastraceloc=saslog nostsuffix;

%let SCHEMA=gersta;


libname myhive hadoop server="&HIVESERVER." user="&SCHEMA." subprotocol=hive2 schema=&SCHEMA.;


libname a "C:\DATEN\MINING\CHURN_BANK";
data myhive.BANK_TRAIN;
 set a.BANK_TRAIN;
run;
 
data myhive.BANK_SCORE;
 set a.BANK_SCORE;
run;
