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

/* ---------------------------------------------------- */
libname myhvex hadoop subprotocol=hive2 port=&HIVE_SRV_PORT.
    host="&HIVE_SRV_HOSTNAME." schema=&HIVE_SCHEMA.
    DBCREATE_TABLE_OPTS="&HIVE_TBL_OPTS.";

/* ---------------------------------------------------- */
proc delete data=myhvex.dqtest_results; run;


/* ---------------------------------------------------- */
data dqtest; 
     ID= _n_; 
     length Name $50; 
     input Name $char50.;
datalines;
BETH HOGAN
Janet viselli
Sarah Gillis
Bill hotchkiss
dr karen leary, phd
Matthew Mullen
BARB Desisti
Kelly M. Howell
Richard Benjamin II
William Howey
Carrie Govelitz
mr. Michael Steed
Dan DePumpo
Brauer, Robert Joseph
Thomas Martin jr 
run;

data myhvex.dqtest; 
	set dqtest;
run;

/* ---------------------------------------------------- */
proc ds2 bypartition=yes ds2accel=yes;

     thread t_pgm / overwrite=yes; 
          dcl package dq dq(); 

          dcl varchar(256) _ERR_;
          dcl varchar(256) Standardized;
          keep ID Name Standardized _ERR_; 

          method check_err(); 
              _ERR_ = null;
              if dq.hasError() then _ERR_ = dq.getError(); 
          end; 

          method init(); 
              dq.loadLocale('ENUSA'); 
          end; 

          method run(); 
              set myhvex.dqtest; 
              Standardized = dq.standardize('Name', Name); 
              check_err();
              output; 
          end;

     endthread;

     data myhvex.dqtest_results (overwrite=yes); 
          declare thread t_pgm t; 

          method run(); 
              set from t; 
          end;

     enddata;

run; quit;


/* ---------------------------------------------------- */
proc print data=myhvex.dqtest_results;
run;

proc delete data=myhvex.dqtest_results; run;
