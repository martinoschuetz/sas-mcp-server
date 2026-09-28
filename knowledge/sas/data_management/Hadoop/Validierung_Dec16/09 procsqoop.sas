/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;
OPTIONS SET=SAS_HADOOP_RESTFUL=1 ;

/* ---------------------------------------------------- */
%put ****    *** Checking if Hadoop environment variables have been set ***;
%put ****        OK ... SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put ****        OK ... SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);

%let HIVE_SRV_HOSTNAME=inthadoop1.ger.sas.com;
%let MYSQL_SRV_HOSTNAME=inthadoop1.ger.sas.com;
%let MYSQL_TESTUSER=sasmysql;
%let MYSQL_PASSWD=Orion123;
%let SAS_TESTUSER=gerhje;


/* ---------------------------------------------------- */
LIBNAME mysqldat MYSQL  MYSQL_PORT=3306  SERVER="&MYSQL_SRV_HOSTNAME."  
	DATABASE=data4sas  USER=&MYSQL_TESTUSER.  
	PASSWORD="&MYSQL_PASSWD.";


/* ---------------------------------------------------- */
proc delete data=mysqldat.mycars; run;
data mysqldat.mycars;
	set sashelp.cars;
run;

proc hadoop verbose;
   hdfs delete ="/user/&SAS_TESTUSER./mycars" recurse;
run;

proc sqoop
	hadoopuser= "&SAS_TESTUSER."
	dbuser=     "&MYSQL_TESTUSER." dbpwd="&MYSQL_PASSWD."
	oozieurl=   "http://&HIVE_SRV_HOSTNAME.:11000/oozie"
	namenode=   "hdfs://&HIVE_SRV_HOSTNAME.:8020"
	jobtracker= "&HIVE_SRV_HOSTNAME.:8050"
	wfhdfspath= "hdfs://&HIVE_SRV_HOSTNAME.:8020/user/&SAS_TESTUSER./myworkflow.xml"
	deletewf
	command=    " import --connect jdbc:mysql://&MYSQL_SRV_HOSTNAME.:3306/data4sas -m 1 --table mycars --target-dir /user/&SAS_TESTUSER./mycars ";
run;

proc hadoop verbose;
   hdfs ls ="/user/&SAS_TESTUSER./mycars";
   hdfs cat ="/user/gerhje/mycars/part-m-00000";   
run;
