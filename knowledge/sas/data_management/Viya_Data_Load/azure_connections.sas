/* # LIBNAME Statement for Azure File Share Location */

libname azshrlib "/mnt/myazurevol/data" ;

data azshrlib.fish_sas ;
set sashelp.fish ;
run;

Proc SQL;
select * from azshrlib.fish_sas ;
run;quit;



/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="eurigmviya4adls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f" ;
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

libname orclib ORC "/sample_data"
      storage_account_name =&MYSTRGACC
      storage_file_system =&MYSTRGFS
      storage_dns_suffix = "dfs.core.windows.net"
      storage_application_id=&MYAPPID
      storage_tenant_id=&MYTNTID
      DIRECTORIES_AS_DATA=YES
      FILE_NAME_EXTENSION=(orc ORC)
;

data orclib.fish_orc;
   set sashelp.fish;
run;



/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="eurigmviya4adls2";
%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f" ;
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

libname orclibN ORC "/sample_data/fish_n_files"
      storage_account_name = &MYSTRGACC
      storage_file_system = &MYSTRGFS
      storage_dns_suffix = "dfs.core.windows.net"
      storage_application_id=&MYAPPID
      storage_tenant_id=&MYTNTID
      DIRECTORIES_AS_DATA=YES
      FILE_NAME_EXTENSION=(orc ORC)
;

data orclibN.fish_0;
   set sashelp.fish;
   where species='Roach';
run;

data orclibN.fish_1;
   set sashelp.fish;
   where species='Bream';
run;

data orclibN.fish_2;
   set sashelp.fish;
   where species='Perch';
run;



/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="eurigmviya4adls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f" ;
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

libname orclib ORC "/sample_data"
      storage_account_name =&MYSTRGACC
      storage_file_system =&MYSTRGFS
      storage_dns_suffix = "dfs.core.windows.net"
      storage_application_id=&MYAPPID
      storage_tenant_id=&MYTNTID
      DIRECTORIES_AS_DATA=YES
      FILE_NAME_EXTENSION=(orc ORC)
;

PROC SQL ;
select * from orclib.fish_n_files ;
run;

data work.fish_new;
   set orclib.fish_n_files;
run;



/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="eurigmviya4adls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f" ;
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

options azuretenantid= &MYTNTID;

filename out adls "sasfile/example.txt"
applicationid=&MYAPPID
accountname=&MYSTRGACC
filesystem=&MYSTRGFS
;

data _null_;
   file out;
   put 'line 1';
   put 'line 2';
run;



CAS mySession  SESSOPTS=(CASLIB=casuser TIMEOUT=99 LOCALE="en_US" metrics=true);

CASLIB azlib path="/mnt/myazurevol/data" ;

proc casutil incaslib="azlib" outcaslib="azlib";
load data=sashelp.cars casout="cars" replace;
save casdata="cars" casout="cars"   replace;
list files;
quit;

proc casutil incaslib="azlib" outcaslib="azlib";
load casdata="cars.sashdat" casout="cars_new" replace;
list tables;
quit;

CAS mySession  TERMINATE;



/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="eurigmviya4adls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f" ;
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

CAS mySession  SESSOPTS=(CASLIB=casuser TIMEOUT=99 LOCALE="en_US" metrics=true);

caslib ADLS2 datasource=(
      srctype="adls",
      accountname=&MYSTRGACC,
      filesystem=&MYSTRGFS,
      dnsSuffix=dfs.core.windows.net,
      timeout=50000,
      tenantid=&MYTNTID ,
      applicationId=&MYAPPID
   )
   path="sample_data/"
   subdirs;

proc casutil incaslib="ADLS2";
   list files ;
run;

/* Save CAS Data to ADLS2 storage data file (orc, csv) */
proc casutil incaslib="ADLS2" outcaslib="ADLS2" ;
load data=sashelp.cars casout="cars" replace;
save casdata="cars" casout="cars.orc"  replace;
save casdata="cars" casout="cars.csv"  replace;
*list files;
quit;

/* Save CAS Data to ADLS2 storage data file (parquet) */
proc casutil incaslib="ADLS2" outcaslib="ADLS2" ;
load data=sashelp.cars casout="cars" replace;
save casdata="cars" casout="cars.parquet"  replace;
*list files;
quit;


/* CAS load from ADLS2 storage data file */
proc casutil  incaslib="ADLS2"  outcaslib="ADLS2";
  load casdata="cars.orc" casout="cars_orc" replace ;
  load casdata="sample_data/cars.parquet" casout="cars_parquet" replace ;
  load casdata="cars.csv" casout="cars_csv" replace ;
  *list tables ;
run;
quit;

cas mysession terminate;
