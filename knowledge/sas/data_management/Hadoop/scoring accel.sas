%LET _CLIENTTASKLABEL='scoring accel';
%LET _CLIENTPROJECTPATH='D:\Projekte\otto\demo_inthadoop1.egp';
%LET _CLIENTPROJECTNAME='demo_inthadoop1.egp';
%LET _SASPROGRAMFILE=;

ODS PATH work.templat(update) sasuser.templat(read) sashelp.tmplmst(read);

/* ---------------------------------------------------- */
proc hadoop verbose;
     hdfs mkdir="/user/gerhje/sasmodels";
     hdfs mkdir="/user/gerhje/sashdmd";
     hdfs mkdir="/user/gerhje/sashdmd/data";
     hdfs mkdir="/user/gerhje/sashdmd/meta";
run;


/* ---------------------------------------------------- */
%let HCP=%sysget(SAS_HADOOP_CONFIG_PATH);
%LET INDCONN=%str(hadoop_cfg=&HCP.);

%indhd_publish_model(
     dir=/home/gerhje/scoring
     , datastep=score.sas 
     , xml=score.xml 
     , modeldir=/user/gerhje/sasmodels
     , modelname=SCORE_HMEQ
     , action=replace 
/*     , trace=yes */
);


/* ---------------------------------------------------- */
libname myhdmd HADOOP server="inthadoop1.ger.sas.com"
     HDFS_PERMDIR="/user/gerhje/sashdmd/data"
     HDFS_METADIR="/user/gerhje/sashdmd/meta";
libname sassamp "/home/gerhje/scoring";

proc delete data=myhdmd.hmeq_scored; run;
proc delete data=myhdmd.hmeq; run;

data myhdmd.hmeq;
     set sassamp.hmeq;
run;


/* ---------------------------------------------------- */
%indhd_run_model( 
     inmetaname=  /user/gerhje/sashdmd/meta/hmeq.sashdmd 
     , outdatadir=/user/gerhje/sashdmd/data/hmeq_scored
     , outmetadir=/user/gerhje/sashdmd/meta/hmeq_scored.sashdmd
     , scorepgm=  /user/gerhje/sasmodels/SCORE_HMEQ/SCORE_HMEQ.ds2 
     , forceoverwrite=false 
     , showproc=yes
/*     , trace=yes */
); 


/* ---------------------------------------------------- */
proc hadoop verbose;
     hdfs delete="/user/gerhje/sasmodels" recurse;
     hdfs delete="/user/gerhje/sashdmd" recurse;
run;

libname myhdmd clear;
libname sassamp clear;

ods path reset;


%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

