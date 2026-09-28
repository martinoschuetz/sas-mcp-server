/* ------------------------------------------------------------------------- */
/* GLOBAL HADOOP/HIVE OPTIONS                                                          */
/* ------------------------------------------------------------------------- */
/*Hadoop-Optionen (sind schon automatisch über die sasv9.cfg gesetzt, ihr braucht sie also NICHT mehr in euren Codes abzusetzen):*/
/*
OPTION SET=SAS_HADOOP_JAR_PATH="/opt/sas/config/Lev1/HadoopServer/lib";
OPTION SET=SAS_HADOOP_CONFIG_PATH="/opt/sas/config/Lev1/HadoopServer/conf";
*/

%put ****        OK ... SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put ****        OK ... SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);

/* ------------------------------------------------------------------------- */
%let HIVESERVER=inthadoop1.ger.sas.com;
%let HIVEPORT=10000;
%let USER=germsz;
%let SCHEMA=germsz;

option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;

/* ------------------------------------------------------------------------- */
/* Global HP Procs Options                                                   */
/* ------------------------------------------------------------------------- */

%LET LASRPORT=10112; /*LASR PORT auf germsz's running LASR */
%LET LASRHOST=inthpa1.ger.sas.com;
%LET GRIDINSTLLLOC=/opt/sas/TKGrid_REP;	/* mit Embedded Process */
/*%LET GRIDINSTLLLOC=/opt/sas/TKGrid;*/		/* ohne Embedded Process */	

OPTION SET=GRIDINSTALLLOC="&GRIDINSTLLLOC.";
OPTION SET=GRIDHOST="&LASRHOST.";

proc delete data=hvgermsz.class; run;
data hvgermsz.class;
	set sashelp.class;
run;

/* ------------------------------------------------------------------------- */
/* Set libs to HIVE and LASR: Already pre-assigned                           */
/* ------------------------------------------------------------------------- */
/*
LIBNAME bsgermsz BASE "/hadoop/exchange/dump/users/germsz";
LIBNAME hvgermsz HADOOP  PORT=10000 SERVER="inthadoop1.ger.sas.com"  SCHEMA=germsz  USER=germsz  PASSWORD="{sas002}97ECE44B0F19E0DE0F1E0782" ;
LIBNAME vagermsz SASIOLA  TAG=hvgermsz  PORT=10112 SIGNER="http://inthpa1.ger.sas.com:7980/SASLASRAuthorization"  HOST="inthpa1.ger.sas.com" ;
*/
/*
proc lasr create PORT=&LASRPORT. path="/opt/sas/lasrsig" tablemem=80
     signer="http://&LASRHOST.:7980/SASLASRAuthorization";
     performance host="&LASRHOST." install="/opt/sas/TKGrid_REP" nodes=all;
run;
*/
LIBNAME myva SASIOLA  TAG=va&USER.  PORT=&LASRPORT. 
     SIGNER="http://&LASRHOST.:7980/SASLASRAuthorization"  
     HOST="&LASRHOST.";
/*
LIBNAME va&USER. SASIOLA TAG=va&USER. PORT=&LASRPORT. SIGNER="http://inthpa1.ger.sas.com:7980/SASLASRAuthorization" HOST="inthpa1.ger.sas.com";

proc lasr term PORT=&LASRPORT.; run;
*/

libname myhive hadoop schema="&SCHEMA." user="&USER."
	host="&HIVESERVER." port=&HIVEPORT. SUBPROTOCOL=hive2
	properties="hive.execution.engine=tez;hive.vectorized.execution.enabled=true;hive.vectorized.execution.reduce.enabled=true" 
	DBCREATE_TABLE_OPTS="STORED AS ORC";

/* SASHDAT Library. Parallel, symmetrischer Datenzugriff auf HDFS*/
/*libname hdatLib sashdat path="&USER.";*/

libname sasdata base "/hadoop/exchange/dump";
