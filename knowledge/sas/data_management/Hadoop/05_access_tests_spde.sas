%let Num_GB=1;

/* ------------------------------------------------------------------------- */
data shaketestfile;
        array x{100};
        array c{100};
        do i=1 to 625000 * &Num_GB;
          do j=1 to 100;
                x{j}=ranuni(2);
                c{j}=int(ranuni(1)*4);
          end;
          y=int(ranuni(1)*2);
          joinvalue=int(ranuni(1)*20);
        output;
        end;
run;


/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing Hive                                                        */
/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 
	schema=&SCHEMA. properties="hive.execution.engine=tez";

proc delete data=myhive.shaketestfile;run;
data myhive.shaketestfile;
	set shaketestfile;
run;

/* approx. 20 seconds */
proc sql;
	create table local_extract as 
		select * from myhive.shaketestfile
			where x5 > 0.99;
quit;

/* ------------------------------------------------------------------------- */
/* ( 2 ) Testing SPDE                                                        */
/* ------------------------------------------------------------------------- */
*filename cfg "&SAS_HADOOP_CONFIG_XML.";

* prepare folder structure;
proc hadoop /*cfg=cfg*/ username="&SCHEMA." verbose;
*	hdfs delete="/user/&USER./spde";
	hdfs mkdir="/user/&USER./spde";
run;

/* SPDE Engine auf Hadoop */
libname myspde spde "/user/&USER./spde" hdfshost=&HIVESERVER. hdfsport=8020;

proc delete data=myspde.shaketestfile;run;
data myspde.shaketestfile;
  set shaketestfile;
run;

/* approx. 25 seconds */
proc sql;
	create table local_extract as 
		select * from myspde.shaketestfile
			where x5 > 0.99;
quit;


/* ------------------------------------------------------------------------- */
/* ( 3 ) Delete records                                                      */
/* ------------------------------------------------------------------------- */
proc sql;
	/* approx 9 minutes */
	delete from myspde.shaketestfile
		where x5 > 0.99;
	/* cannot submit, error */
	delete from myhive.shaketestfile
		where x5 > 0.99;
quit;


libname myhive clear;
libname myspde clear;
