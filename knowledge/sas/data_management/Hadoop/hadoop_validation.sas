/* ************************************************************************* */
/* Hadoop Validation Snippets                                                */

/* ------------------ */
/* HDFS Commands      */
filename cfg "/sas/hadoop/core-site.xml";
proc hadoop options=cfg username="hadoop" password="SASpw1" verbose;
     hdfs mkdir="/user/hadoop/testfolder";
run;

/* ------------------ */
/* Pig Commands       */
filename cfg "/sas/hadoop/core-site.xml";
filename pig "/hadoop/pig-0.10.0/scripts/test-hadoop.pig";
proc hadoop options=cfg username="hadoop" password="SASpw1" verbose;
     hdfs copyfromlocal="/hadoop/pig-0.10.0/tutorial/data/excite-small.log"
	 	out="/hps" overwrite;
	pig code=pig;
run;

/* ------------------ */
/* MapReduce Commands */
/* THUP:Need management decision on whether to support MapReduce and Pig on HortonWorks YARN */
/* http://sww.sas.com/ds/DefectsSearch/S0955/S0955112.html */
/* 
NISLEY, AMBER:20Mar2013 at 11:08:39:
Currently, Proc Hadoop is only supported on MapReduce version 1 - there needs to
be a decision made on whether to support version 2, also known as YARN (this
affects the support of SAS Interface to Hadoop with HortonWorks).

MAHER, SALMAN:24Jul2013 at 09:22:35:
Pulling back to 94m1 to see what is need to support YARN as it is becoming the
default for many vendors.
*/
/*
filename cfg "/sas/hadoop/core-site.xml";
proc hadoop options=cfg username="hadoop" password="SASpw1" verbose;
	mapreduce 
		jar="/sas/config/Lev1/SASApp/mapreduce/com.sas.ger.tpm.sample.wordcount.jar"
		input="/hps/kafka_verwandlung.txt"
		output="/hps/mr_results"
	;
run;
*/


/* ------------------ */
/* Hive Commands (I)  */
options sastrace=',,,d' sastraceloc=saslog nostsuffix;
libname myhive hadoop config="/sas/hadoop/core-site.xml"
	server="sasva-sas.local" port=5111 schema=default user="hadoop" password="SASpw1";

/* note: create table hive.a as select * from hive.b -> download to work area */
proc sql;
	create table class2 as
		select * from myhive.class
			where age < 14;
quit;


/* ------------------ */
/* Hive Commands (II) */
options sastrace=',,,d' sastraceloc=saslog nostsuffix;
proc sql;
	connect to hadoop(port=5111 server="sasva-sas.local" user="hadoop" password="SASpw1");
	execute(drop table class2) by hadoop;
	execute(create table class2 as
		select * from class
			where age < 14) by hadoop;
	disconnect from hadoop;
quit;
