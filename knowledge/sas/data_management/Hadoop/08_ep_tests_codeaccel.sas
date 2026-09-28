options dsaccel="any" ds2accel="any";

/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing DataStep Code Accelerator                                   */
/* ------------------------------------------------------------------------- */
filename cfg "&SAS_HADOOP_CONFIG_XML.";

* prepare folder structure;
proc hadoop cfg=cfg username="&USER." verbose;
	hdfs delete="/user/&USER./sashdmd/data";
	hdfs delete="/user/&USER./sashdmd/meta";

	hdfs mkdir="/user/&USER./sashdmd";
	hdfs mkdir="/user/&USER./sashdmd/data";
	hdfs mkdir="/user/&USER./sashdmd/meta";
run;

/* ------------------------------------------------------------------------- */
/* *** NOTE: do NOT enclose the username with quotation marks here       *** */
/* *** (DataStep Code Accelerator passes them to Hadoop)                 *** */
libname myhdmd clear;
libname myhdmd HADOOP user=&USER. server="&HIVESERVER."
	HDFS_PERMDIR="/user/&USER./sashdmd/data"
	HDFS_METADIR="/user/&USER./sashdmd/meta";


/* ------------------------------------------------------------------------- */
proc delete data=myhdmd.class; run;
proc delete data=myhdmd.class_bmi;run;
data myhdmd.class;
	set sashelp.class;
run;

* run datastep in Hadoop (check log);
data myhdmd.class_bmi;
	set myhdmd.class;
	bmi = weight / height;
run;

libname myhdmd clear;


/* ------------------------------------------------------------------------- */
/* ( 2 ) Testing DS2 Code Accelerator -- 1                                   */
/* ------------------------------------------------------------------------- */
libname myhdmd HADOOP user="&USER." server="&HIVESERVER."
	HDFS_PERMDIR="/user/&USER./sashdmd/data"
	HDFS_METADIR="/user/&USER./sashdmd/meta";


/* ------------------------------------------------------------------------- */
proc delete data=myhdmd.cars; run;
proc delete data=cars_avrg; run;
proc delete data=compute;run;

proc sort data=sashelp.cars out=cars;
	by type;
run;
data myhdmd.cars;
	set cars;
run;

/* ------------------------------------------------------------------------- */
proc ds2 DS2ACCEL=yes;
	ds2_options trace;

	thread compute / overwrite=yes;
		dcl double avrg cnt;
		method run();
			set myhdmd.cars;
			by type;
			if first.type then do;
				avrg = 0;
				cnt  = 0;
			end;
			cnt + 1;
			avrg + weight;
			if last.type then do;
				avrg = avrg / cnt;
				output;
			end;
		end;
	endthread;

	data cars_avrg;
		dcl thread compute t;
		method run();
			set from t;
		end;
	enddata;

run; quit;


/* ------------------------------------------------------------------------- */
/* ( 2 ) Testing DS2 Code Accelerator -- 2                                   */
/* ------------------------------------------------------------------------- */
proc delete data=compute;run;
proc delete data=myhdmd.cars_transposed;run;

/* ------------------------------------------------------------------------- */
/* DS2 transpose: avg invoice by type for each origin */
proc ds2 indb=yes;
	ds2_options trace;

	thread compute;
		dcl double europe_invoice;
		dcl double usa_invoice;
		dcl double asia_invoice;
		dcl double n;

		method run();
			set myhdmd.cars;
			by type;

			if first.type then do;
				europe_invoice = 0;
				usa_invoice    = 0;
				asia_invoice   = 0;
				n              = 0;
			end;

			if trim(origin)      eq 'Europe' then europe_invoice + invoice;
			else if trim(origin) eq 'Asia' then asia_invoice + invoice;
			else if trim(origin) eq 'USA' then usa_invoice + invoice;

			n + 1;
			if last.type then do;
				asia_invoice   = (asia_invoice / n);
				usa_invoice    = (usa_invoice / n);
				europe_invoice = (europe_invoice / n);
				output;
			end;
		end;
	endthread;

	data myhdmd.cars_transposed(keep=(type europe_invoice usa_invoice asia_invoice n));
		dcl thread compute t;
		method run();
			set from t;
		end;
	enddata;
run; quit;

/* ------------------------------------------------------------------------- */
proc print data=myhdmd.cars_transposed;run;

libname myhdmd clear;
