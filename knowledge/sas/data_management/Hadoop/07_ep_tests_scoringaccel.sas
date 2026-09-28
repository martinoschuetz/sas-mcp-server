/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing Scoring Accelerator                                         */
/* ------------------------------------------------------------------------- */
filename cfg "&SAS_HADOOP_CONFIG_XML.";

* prepare folder structure;
*proc hadoop cfg=cfg username="&USER." verbose;

proc hadoop username="&USER." verbose;
/*	hdfs delete="/user/&USER./sashdmd/data";  
	hdfs delete="/user/&USER./sashdmd/meta"; 
	hdfs delete="/user/&USER./sashdmd";
	hdfs delete="/user/&USER./sasmodels";
*/
	hdfs mkdir="/user/&USER./sasmodels";
	hdfs mkdir="/user/&USER./sashdmd";
	hdfs mkdir="/user/&USER./sashdmd/data";
	hdfs mkdir="/user/&USER./sashdmd/meta";
run;

/* 
	HDFS_DATADIR='path' alias HDFS_PERMDIR=
	When not in Hive mode, specifies the path to the Hadoop directory where SAS reads and writes data (for example, ‘/sas/hpa’).
	Use this option only when you are not using Hive or HiveServer2.
	For details, see the “Accessing Data Independently from Hive” topic in the Base SAS Procedures Guide

	HDFS_METADIR='path'
	Specifies the path to an HDFS directory that contains XML-based table definitions, called SASHDMD descriptors.
	Through these descriptors, SAS then accesses the data using HDFS instead of Hive.
	If you want the Hadoop engine to connect to Hive and use HiveQL, do not set this option.
*/
libname myhdmd HADOOP user="&USER." server="&HIVESERVER."
	HDFS_PERMDIR="/user/&USER./sashdmd/data"
	HDFS_METADIR="/user/&USER./sashdmd/meta";
libname sassamp "C:\Program Files\SASHome\SASFoundation\9.4\hps\sample";

proc delete data=myhdmd.hmeq; run;
data myhdmd.hmeq;
	set sassamp.hmeq;
run;
/* Beispiel Code für den SAS Scoring Accelerator */
/* ------------------------------------------------------------------------ */
%LET INDCONN=%STR(HADOOP_CFG=&SAS_HADOOP_CONFIG_XML. USER=&USER. PASSWD=SASpw1);

%indhd_publish_model(
	dir=C:\Temp\HMEQ_Score_Code
	, datastep=score.sas 
	, xml=score.xml 
	, modeldir=/user/&USER./sasmodels
	, modelname=SCORE_HMEQ
	, action=replace 
	, trace=yes
); 

proc delete data=myhdmd.hmeq_scored; run;
%indhd_run_model( 
	inmetaname=  /user/&USER./sashdmd/meta/hmeq.sashdmd 
	, outdatadir=/user/&USER./sashdmd/data/hmeq_scored
	, outmetadir=/user/&USER./sashdmd/meta/hmeq_scored.sashdmd
	, scorepgm=  /user/&USER./sasmodels/SCORE_HMEQ/SCORE_HMEQ.ds2 
	, forceoverwrite=false 
	, showproc=yes /* showproc and trace are debug options */ 
	, trace=no
); 


/* ------------------------------------------------------------------------ */
proc print data=myhdmd.hmeq_scored(obs=10); run;


libname myhdmd clear;
libname sassamp clear;
