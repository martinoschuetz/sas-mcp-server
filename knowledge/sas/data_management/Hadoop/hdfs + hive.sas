%LET _CLIENTTASKLABEL='hdfs + hive';
%LET _CLIENTPROJECTPATH='D:\Projekte\otto\demo_inthadoop1.egp';
%LET _CLIENTPROJECTNAME='demo_inthadoop1.egp';
%LET _SASPROGRAMFILE=;

/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;
option set=SAS_HADOOP_RESTFUL=1;

/* ---------------------------------------------------- */
%put SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);


/* ---------------------------------------------------- */
/* 00_base_hadoop.sas                                   */
/* ---------------------------------------------------- */
filename out "/tmp/prdsale.tsv";
data _null_;
        set sashelp.prdsale;
        file out;
        attrib row format=$256.;
        row = cats(actual, "09"x, predict, "09"x, country, "09"x, region, "09"x,
                division, "09"x, prodtype, "09"x, product, "09"x, quarter, "09"x,
                year, "09"x, month);
        put row;
run;

proc hadoop verbose;
   hdfs mkdir="/tmp/sastest";
   hdfs copyFromLocal="/tmp/prdsale.tsv" out="/tmp/sastest" overwrite;
   hdfs copyToLocal="/tmp/sastest/prdsale.tsv" out="/tmp/prdsale.tsv.2" overwrite;
run;

proc hadoop;
	hdfs ls="/tmp/sastest" out="/tmp/hdfsscratch" RECURSE;
run;

filename hdfsf "/tmp/hdfsscratch";
data hdfsfiles;
	LENGTH
		Perms            $ 11
		Owner            $ 9
		Group            $ 9
		FSize              8
		FDate              8
		FTime              8
		FPath            $ 37 ;
	FORMAT
		perms            $CHAR11.
		owner            $CHAR9.
		group            $CHAR10.
		fsize            BEST18.
		FDate            YYMMDD10.
		FTime            TIME8.
		fpath            $CHAR37. ;

	infile hdfsf LRECL=32767 ENCODING="LATIN1" TRUNCOVER ;
    INPUT
        @1     perms            $CHAR11.
        @12    owner            $CHAR9.
        @21    group            $CHAR9.
        @31    fsize            ?? BEST18.
        @49    fdate            ?? YYMMDD11.
        @60    FTime            ?? TIME9.
        @69    fpath            $CHAR37. ;
run;

proc hadoop verbose;
   hdfs delete ="/tmp/sastest" recurse;
run;


/* ---------------------------------------------------- */
/* 02_access2hadoop.sas                                 */
/* ---------------------------------------------------- */

libname myhive hadoop subprotocol=hive2 port=10000
    host="inthadoop1.ger.sas.com" schema=gerhje;

libname myhvex hadoop subprotocol=hive2 port=10000
    host="inthadoop1.ger.sas.com" schema=gerhje
    DBCREATE_TABLE_OPTS="STORED AS ORC";


/* ---------------------------------------------------- */
proc delete data=myhive.sascars; run;
proc delete data=myhive.sascars_as_orc; run;
proc delete data=myhive.sasprdsal2; run;
proc delete data=myhive.sasprdsal2_aggr; run;


data myhive.sascars;
    set sashelp.cars;
run;

data myhvex.sascars_as_orc;
    set sashelp.cars;
run;

proc sql;
	create table myhive.sasprdsal2 as
		select * From sashelp.prdsal2;
quit;

proc sql;
	connect to hadoop(subprotocol=hive2 port=10000
        host="inthadoop1.ger.sas.com" schema=gerhje);
    
    execute(
        create table gerhje.sasprdsal2_aggr as
            select max(actual) as actual, country, prodtype, product, year
                from gerhje.sasprdsal2
                group by country, prodtype, product, year
    ) by hadoop;
    
    disconnect from hadoop;
quit;

proc summary data=myhive.sasprdsal2;
     var actual;
     output out=summary MIN= MAX= N= / autoname;
run;



%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

