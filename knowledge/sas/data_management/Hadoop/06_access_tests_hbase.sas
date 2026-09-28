options dsaccel="any" ds2accel="any";

/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&USER." subprotocol=hive2 
	schema=&SCHEMA.;


proc sql;
	connect to hadoop(port=10000 server="&HIVESERVER." user="&USER." 
		subprotocol=hive2 schema=&SCHEMA.);
	execute(drop table &USER..hbase1) by hadoop;
	execute(
		CREATE TABLE &USER..hbase1(key int, value string) 
			STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
			WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,cf1:val")
			TBLPROPERTIES ("hbase.table.name" = "&SCHEMA._hbase1")
	) by hadoop;
	disconnect from hadoop;
quit;


/* ------------------------------------------------------------------------- */
/* Testing read/write access to HBase via Hive                               */
/* ------------------------------------------------------------------------- */
data test;
	attrib key length=8 value length=$10;
	do key = 1 to 1000;
		value = cats("value",key);
		output;
	end;
run;

proc sql;
	insert into myhive.hbase1 
		select * from test;
quit;

proc sql;
	create table test1 as
		select * from myhive.hbase1 where key < 100;
quit;
