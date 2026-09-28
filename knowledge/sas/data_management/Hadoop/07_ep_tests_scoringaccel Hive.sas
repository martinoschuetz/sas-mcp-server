/* Copy test data to hive */
/*
libname mydata "/opt/sas/SASHome/SASFoundation/9.4/samples/hps";

data myhive.hmeq;
	set hans.hmeq;
run;
*/

%let hdfs_root=/sas_dm;

proc hadoop verbose;
	hdfs delete="&hdfs_root./sasmodels";
	hdfs delete="&hdfs_root./sashdmd";
	hdfs delete="&hdfs_root./sashdmd/meta";
	hdfs delete="&hdfs_root./sashdmd/data";
run;

proc hadoop verbose;
	hdfs mkdir="&hdfs_root./sasmodels";
	hdfs mkdir="&hdfs_root./sashdmd";
	hdfs mkdir="&hdfs_root./sashdmd/meta";
	hdfs mkdir="&hdfs_root./sashdmd/data";
run;

libname myhdmd HADOOP server="&HIVESERVER."
     HDFS_PERMDIR="&hdfs_root./sashdmd/data"
     HDFS_METADIR="&hdfs_root./sashdmd/meta";

%LET INDCONN=%STR(HADOOP_CFG=%sysget(SAS_HADOOP_CONFIG_PATH));

%indhd_publish_model(
	dir=/tmp
	, datastep=score.sas 
	, xml=score.xml 
	, modeldir=&hdfs_root./sasmodels
	, modelname=KaggleNumeric
	, action=replace 
	, trace=yes
); 

proc delete data=myhdmd.hmeq_scored; run;
%indhd_run_model(
	inputtable=myhive.hmeq 
	, outdatadir=&hdfs_root./sashdmd/data/hmeq_scored
	, outmetadir=&hdfs_root./sashdmd/meta/hmeq_scored.sashdmd
	, scorepgm=  &hdfs_root./sasmodels/KaggleNumeric/KaggleNumeric.ds2 
	, forceoverwrite=false 
	, showproc=yes /* showproc and trace are debug options */ 
	, trace=no
); 

/* Ab 9.4 M5 direktes lesen und schreiben in HIVE */
%indhd_run_model(
	inputtable=myhive.hmeq
	, outputtable=myhive.hmeq_scores 
	, scorepgm=  &hdfs_root./sasmodels/KaggleNumeric/KaggleNumeric.ds2 
	, forceoverwrite=false 
	, showproc=yes /* showproc and trace are debug options */ 
	, trace=no /*
	, keep=id EM_CLASSIFICATION EM_EVENTPROBABILITY EM_PROBABILITY
	, formatfile=/data/scoring/orc/ds2/almush01_orc/almush01_orc_ufmt.xml*/
); 

proc print data=myhdmd.hmeq_scored(obs=10); run;


libname mydata clear;
libname myhdmd clear;





