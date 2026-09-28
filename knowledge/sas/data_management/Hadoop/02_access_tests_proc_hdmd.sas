/* ------------------------------------------------------------------------- */
/* ( 5 ) Testing PROC HDMD                                                   */
/* ------------------------------------------------------------------------- */
*filename cfg "&SAS_HADOOP_CONFIG_XML.";

* prepare folder structure;
proc hadoop /*cfg=cfg*/ username="&USER." verbose;
	hdfs delete="/user/&SCHEMA./sashdmd/data";
	hdfs delete="/user/&SCHEMA./sashdmd/meta";

	hdfs mkdir="/user/&SCHEMA./sashdmd";
	hdfs mkdir="/user/&SCHEMA./sashdmd/data";
	hdfs mkdir="/user/&SCHEMA./sashdmd/meta";
run;

* prepare sample data (json data);
proc json out="c:\temp\heart.json" pretty;
	export sashelp.heart;
run;

* copy json file to Hadoop;
filename in "c:\temp\heart.json";
filename out hadoop "/user/&SCHEMA./sashdmd/data/heart.json" debug /*cfg=cfg*/ user="&SCHEMA.";
data _null_;
	file out;
	infile in;
	input;
	put _infile_;
run;

* generate SAS metadata for json file;
libname myhdmd HADOOP user="&SCHEMA." server="&HIVESERVER."
	HDFS_PERMDIR="/user/&SCHEMA./sashdmd/data"
	HDFS_METADIR="/user/&SCHEMA./sashdmd/meta";

proc hdmd name=myhdmd.heart_json 
	format=json encoding=utf8
	data_file="heart.json"
;
	column Status Char(5)          tag="Status";   
	column DeathCause Char(26)     tag="DeathCause";
	column AgeCHDdiag double       tag="AgeCHDdiag";
	column Sex Char(6)             tag="Sex";
	column AgeAtStart int          tag="AgeAtStart";
	column Height double           tag="Height";  
	column Weight double           tag="Weight";  
	column Diastolic double        tag="Diastolic";  
	column Systolic double         tag="Systolic";  
	column MRW double              tag="MRW";
	column Smoking double          tag="Smoking";  
	column AgeAtDeath double       tag="AgeAtDeath";
	column Cholesterol double      tag="Cholesterol";  
	column Chol_Status Char(10)    tag="Chol_Status";
	column BP_Status Char(7)       tag="BP_Status";
	column Weight_Status Char(11)  tag="Weight_Status";
	column Smoking_Status Char(17) tag="Smoking_Status"; 
run;

* sample query on data;
proc sql;
	create table results as
		select count(*) as c, status, sex
		from myhdmd.heart_json
		group by status, sex;
quit;

libname myhdmd clear;