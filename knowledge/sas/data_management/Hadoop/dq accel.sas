%LET _CLIENTTASKLABEL='dq accel';
%LET _CLIENTPROJECTPATH='D:\Projekte\otto\demo_inthadoop1.egp';
%LET _CLIENTPROJECTNAME='demo_inthadoop1.egp';
%LET _SASPROGRAMFILE=;

/* ---------------------------------------------------- */

libname myhive hadoop subprotocol=hive2 port=10000
    host="inthadoop1.ger.sas.com" schema=gerhje;

proc delete data=myhive.dqtest; run;
proc delete data=myhive.dqtest_results; run;


/* ---------------------------------------------------- */
data myhive.dqtest; 
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
              set myhive.dqtest; 
              Standardized = dq.standardize('Name', Name); 
              check_err();
              output; 
          end;

     endthread;

     data myhive.dqtest_results (overwrite=yes); 
          declare thread t_pgm t; 

          method run(); 
              set from t; 
          end;

     enddata;

run; quit;



%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

