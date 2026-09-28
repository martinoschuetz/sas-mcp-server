/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing FILENAME Statement                                          */
/* ------------------------------------------------------------------------- */

proc hadoop username="&USER." verbose;
	hdfs delete="/user/&USER./buildings.hadoop.csv";
run;

/* Writing data to HDFS */
filename out hadoop "/user/&USER./buildings.hadoop.csv" debug user="&USER.";

data _null_;
	file out;
	length long $1024;
	input;
	long = _infile_;
	long = trim(long);
	put long ' ';
	cards4;
BuildingID,BuildingMgr,BuildingAge,HVACproduct,Country
1,M1,25,AC1000,USA
2,M2,27,FN39TG,France
3,M3,28,JDNS77,Brazil
4,M4,17,GG1919,Finland
5,M5,3,ACMAX22,Hong Kong
6,M6,9,AC1000,Singapore
7,M7,13,FN39TG,South Africa
8,M8,25,JDNS77,Australia
9,M9,11,GG1919,Mexico
10,M10,23,ACMAX22,China
11,M11,14,AC1000,Belgium
12,M12,26,FN39TG,Finland
13,M13,25,JDNS77,Saudi Arabia
14,M14,17,GG1919,Germany
15,M15,19,ACMAX22,Israel
16,M16,23,AC1000,Turkey
17,M17,11,FN39TG,Egypt
18,M18,25,JDNS77,Indonesia
19,M19,14,GG1919,Canada
20,M20,19,ACMAX22,Argentina
;;;;
run;

/* Reading Data fom HDFS */
data buildings;
	infile out dlm='2C'x FIRSTOBS=2;
	input BuildingID BuildingMgr $ BuildingAge HVACproduct $ Country $;
run;

/* ------------------------------------------------------------------------- */
/* ( 2 ) Testing PROC HADOOP                                                 */
/* ------------------------------------------------------------------------- */

proc hadoop /*cfg=cfg*/ username="&USER." verbose;
	hdfs mkdir="/user/&USER./dir1";
	hdfs copytolocal="/user/&USER./buildings.hadoop.csv" out="c:\temp\buildings.win.csv" ;
	hdfs copyfromlocal="c:\temp\buildings.win.csv" out="/user/&USER./dir1/buildings.hadoop.csv" overwrite;
run;

proc hadoop /*cfg=cfg*/ username="&USER." verbose;
	hdfs delete="/user/&USER./dir1/buildings.hadoop.csv";
	hdfs delete="/user/&USER./dir1";
run;

/* ------------------------------------------------------------------------- */
/* ( 3 ) Testing Hive -- 1                                                   */
/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 schema=&SCHEMA.;

proc delete data=myhive.cars;run;
proc delete data=myhive.class;run;
proc delete data=myhive.prdsal2;run;

proc sql;
	create table myhive.cars as 
		select * from sashelp.cars;
quit;
data myhive.class;
	set sashelp.class;
run;
data myhive.prdsal2;
	set sashelp.prdsal2;
run;

*libname myhive clear;

proc sql;
	connect to hadoop(port=10000 server="&HIVESERVER." user="&SCHEMA." 
		subprotocol=hive2 schema=&SCHEMA.);
	execute(drop table &SCHEMA..hbase1) by hadoop;
	execute(CREATE TABLE &SCHEMA..hbase1(key int, value string) 
		STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
		WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,cf1:val")
		TBLPROPERTIES ("hbase.table.name" = "&SCHEMA._hbase1")
		) by hadoop;
	disconnect from hadoop;
quit;


/* ------------------------------------------------------------------------- */
/* ( 3 ) Testing Hive -- 2                                                   */
/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 schema=&SCHEMA.;

proc sql;
	create table results as
		select count(*) as n, product 
			from myhive.prdsal2
			group by product;
quit;

libname myhive clear;


/* ------------------------------------------------------------------------- */
/* ( 3 ) Testing Hive -- 3                                                   */
/* ------------------------------------------------------------------------- */
/* use MapReduce execution engine */
libname hivemr hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 schema=&SCHEMA. 
	properties="hive.execution.engine=mr";
/* use Tez execution engine */
libname hivetez hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 schema=&SCHEMA. 
	properties="hive.execution.engine=tez";

proc sql;
	create table results_mr as
		select count(*) as n, product 
			from hivemr.prdsal2
			group by product;
quit;
proc sql;
	create table results_tez as
		select count(*) as n, product 
			from hivetez.prdsal2
			group by product;
quit;

libname hivemr clear;
libname hivetez clear;


/* ------------------------------------------------------------------------- */
/* ( 3 ) Testing Hive -- 4                                                   */
/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 schema=&SCHEMA.;
proc delete data=myhive.results;run;
libname myhive clear;

proc sql;
	connect to hadoop(port=10000 server="&HIVESERVER." user="&USER." 
		subprotocol=hive2 schema=&SCHEMA.);

	/* use Tez execution engine */
	execute(SET hive.execution.engine=tez) by hadoop;
	execute(
		create table &USER..results as
			select count(*) as n, product 
				from &USER..prdsal2
				group by product
	) by hadoop;
	disconnect from hadoop;
quit;


/* ------------------------------------------------------------------------- */
/* ( 4 ) Testing PROC HADOOP / webHDFS                                       */
/* ------------------------------------------------------------------------- */
/* This test uses webHDFS to submit HDFS Commands, so there are no client side 
 * jar files needed
 * 
 * RESTART THIS SAS SESSION TO CLEAR PREVIOUS OPTIONS. SUBMIT CODE STARTING
 * FROM BELOW.
 *
 * Note: hadoop client jar files are still needed for Hive access
 * Note: webHDFS access requires SAS 9.4M2
 */
*%let SAS_HADOOP_CONFIG_XML=C:\Java\inthadoop\xml_concat\hadoop-config.xml;
*%let SCHEMA=&SCHEMA.;

/* ------------------------------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix;
options set=SAS_HADOOP_RESTFUL=1;

filename cfg "&SAS_HADOOP_CONFIG_XML.";

proc hadoop cfg=cfg username="&USER." verbose;
	hdfs mkdir="/user/&USER./dir1";
run;

proc hadoop cfg=cfg username="&USER." verbose;
	hdfs delete="/user/&USER./dir1";
run;
