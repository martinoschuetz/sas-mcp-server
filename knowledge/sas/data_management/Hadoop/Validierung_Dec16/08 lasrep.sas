/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;
options dsaccel="any" ds2accel="any" SQLGENERATION=DBMS;

/* ---------------------------------------------------- */
%put ****    *** Checking if Hadoop environment variables have been set ***;
%put ****        OK ... SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put ****        OK ... SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);

%let HIVE_SRV_HOSTNAME=inthadoop1.ger.sas.com;
%let HIVE_SRV_PORT=10000;
%let HIVE_SCHEMA=sas_managed;
%let HIVE_TBL_OPTS=STORED AS ORC;
%let SAS_TESTUSER=gerhje;
%let TKGRID_ROOT_HOSTNAME=inthpa1.ger.sas.com;
%let TKGRID_INSTALL_DIR=/opt/sas/TKGrid_REP;
%let LASR_PORT=9992;

/* ---------------------------------------------------- */
data myhive.sascars;
    set sashelp.cars;
run;

%macro lsrmeta(trh,lp);

proc imstat;
	serverinfo / host="&trh." port=&lp. save=si;
	store si(1,1)=sik1; store si(1,2)=siv1;
	store si(2,1)=sik2; store si(2,2)=siv2;
	store si(3,1)=sik3; store si(3,2)=siv3;
	store si(4,1)=sik4; store si(4,2)=siv4;
quit;

%put ****       &sik1.: &siv1.;
%put ****       &sik2.: &siv2.;
%put ****       &sik3.: &siv3.;
%put ****       &sik4.: &siv4.;

%mend;


/* ---------------------------------------------------- */
proc lasr create path="/tmp" port=&LASR_PORT. tablemem=80;
    performance host="&TKGRID_ROOT_HOSTNAME." 
      install="&TKGRID_INSTALL_DIR." nodes=all;
run;
%lsrmeta(&TKGRID_ROOT_HOSTNAME., &LASR_PORT.);

proc lasr add data=myhive.sascars port=&LASR_PORT.;
    performance host="&TKGRID_ROOT_HOSTNAME." 
      install="&TKGRID_INSTALL_DIR." details nodes=all;
run;

/* ---------------------------------------------------- */
LIBNAME myhive SASIOLA PORT=&LASR_PORT. HOST="&TKGRID_ROOT_HOSTNAME." tag="myhive";
proc imstat;
     serverinfo / host="&TKGRID_ROOT_HOSTNAME." port=&LASR_PORT.;
     tableinfo  / host="&TKGRID_ROOT_HOSTNAME." port=&LASR_PORT.;
run;quit;


/* ---------------------------------------------------- */
proc lasr stop port=&LASR_PORT.;
    performance host="&TKGRID_ROOT_HOSTNAME." 
      install="&TKGRID_INSTALL_DIR." nodes=all;
run;
