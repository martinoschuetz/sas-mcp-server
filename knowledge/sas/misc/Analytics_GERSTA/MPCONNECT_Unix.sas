%let script=C:\Program Files\SAS Institute\SAS\V8\connect\saslink\tcpunix_sunday.scr;
filename pw "D:\Strategy\SAS_HPF\mpconnect\";
%inc pw("passwd.txt");

/*signon remote 1*/
%let box1=sunday;
options comamid=tcp remote=box1;
filename rlink "&script";
signon;

/*signon remote 2*/
%let box2=sunday;
options comamid=tcp remote=box2;
filename rlink "&script";
signon;

rsubmit box1 wait=no;
   libname data1 "~euruds/data/hpfdata1";
   proc sort data=data1.prod1;by store date;run;
   proc hpf data=data1.prod1 lead=12 outfor=data1.hpffor1;                                                                                                                                                  
     id Date interval=MONTH accumulate=TOTAL;                                                                                                           
     by Store;                                                                                                                                          
     forecast Quantity / model=BEST select=MAPE                                                                                                         
     holdout=0 transform=AUTO;                                                                                                                          
   run;
   proc download data=data1.hpffor1 out=hpffor1;run;quit;
endrsubmit;
/*run HPF on remote 2*/
rsubmit box2 wait=no;
   libname data2 "~euruds/data/hpfdata2";
   proc sort data=data2.prod2;by store date;run;
   proc hpf data=data2.prod2 lead=12 outfor=data2.hpffor2;                                                                                                                                                  
     id Date interval=MONTH accumulate=TOTAL;                                                                                                           
     by Store;                                                                                                                                          
     forecast Quantity / model=BEST select=MAPE                                                                                                         
     holdout=0 transform=AUTO;                                                                                                                          
   run;        
   proc download data=data2.hpffor2 out=hpffor2;run;quit;
endrsubmit;
/* See the processes running in background */
listtask;
/* Wait for both sorts to complete.*/
waitfor _all_ box1 box2;
/*Merge results from both runs*/
data hpffor;
   set hpffor1 hpffor2;
run;
/*Signoff*/
signoff box1;
signoff box2;
filename pw;
