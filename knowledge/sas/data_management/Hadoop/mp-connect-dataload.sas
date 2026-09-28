/* ************************************************************************* */
libname myhive hadoop schema='gerhje' SERVER="inthadoop1.ger.sas.com" port=10000;
libname mytmp "/tmp" ACCESS=READONLY;


/* ************************************************************************* */
%macro ds2hive(task,user,pw,inds,outds,fobs,numrecs,hivepath);
	signon &task. username="&user." password="&pw.";
	%syslput fobs=&fobs.;
	%syslput numrecs=&numrecs.;
	%syslput hivepath=%bquote(%sysfunc(dequote(&hivepath.)));
	%syslput inds=&inds.;
	%syslput outds=&outds.;
	rsubmit &task. wait=no;
		libname myhive hadoop schema="gerhje" SERVER="inthadoop1.ger.sas.com" port=10000;
		libname mytmp "/tmp" ACCESS=READONLY;
		proc delete data=myhive.&outds.; run;
		data myhive.&outds.
			(DBCREATE_TABLE_EXTERNAL=YES DBCREATE_TABLE_LOCATION="&hivepath.");
			set mytmp.&inds. (firstobs=&fobs. obs=%eval(&fobs.+&numrecs.-1));
		run;
	endrsubmit;
%mend;


/* ************************************************************************* */
proc hadoop;
	hdfs mkdir="/tmp/mega" nowarn;
	hdfs delete="/tmp/mega" nowarn;
run;

%let myspawn=inthpa1.ger.sas.com 7551;
options comamid=tcp;

%let t1=&myspawn;
%let t2=&myspawn;
%let t3=&myspawn;
%let t4=&myspawn;
%let t5=&myspawn;
%let t6=&myspawn;

%ds2hive(t1,gerhje,SASpw1,MEGACORP5S_2,test1,       1,3000000,"/tmp/mega/1");
%ds2hive(t2,gerhje,SASpw1,MEGACORP5S_2,test2, 3000001,3000000,"/tmp/mega/2");
%ds2hive(t3,gerhje,SASpw1,MEGACORP5S_2,test3, 6000001,3000000,"/tmp/mega/3");
%ds2hive(t4,gerhje,SASpw1,MEGACORP5S_2,test4, 9000001,3000000,"/tmp/mega/4");
%ds2hive(t5,gerhje,SASpw1,MEGACORP5S_2,test5,12000001,3000000,"/tmp/mega/5");
%ds2hive(t6,gerhje,SASpw1,MEGACORP5S_2,test6,15000001,3000000,"/tmp/mega/6");

waitfor _all_ t1 t2 t3 t4 t5 t6;

signoff t1;
signoff t2;
signoff t3;
signoff t4;
signoff t5;
signoff t6;


/* ************************************************************************* */
proc delete data=myhive.mega_all; run;
proc sql;
    connect to hadoop(subprotocol=hive2 port=10000
            host="inthadoop1.ger.sas.com" schema="gerhje");
    execute(
            create external table gerhje.mega_all 
				like gerhje.test1
				location "/tmp/mega"
    ) by hadoop;
    disconnect from hadoop;
quit;

proc sql;
	select count(*) from myhive.mega_all;
quit;
