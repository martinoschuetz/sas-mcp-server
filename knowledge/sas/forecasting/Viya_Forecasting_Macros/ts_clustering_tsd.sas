/* 	This code performst ime series clustering using the TSD package (DTW object) below. 
	Jay Laramore wrote the IML call that does the conversion you describe, and it’s about half way down. */
	/*  ETSFM0102_1_EDEMO  */

/* pre-processing  */
/* create the Local library if needed */
%if not %sysfunc(exist(local.retail)) %then
	%do;
		libname local '~/workshop/ETSFM';
	%end;

/* create the CAS session and the CASLIB, Mylib if needed */
cas mycas;
libname mylib cas sessref = mycas;

/*** demo, time series clustering ***/
proc contents data=local.clusterdemo;
quit;

data mylib.indat;
	set local.clusterdemo;
	drop y;
run;

* create a macro varible name for the 100 candiate input variables;
data mylib.inmacro;
	set mylib.indat;
	drop date t;
run;

/* note, these sql calls are case sensitive */
Proc sql;
	Select name into : xvar separated by ' '

	From dictionary.columns

	Where libname='MYLIB'

		AND memname='INMACRO';
Quit;

Proc sql;
	Select name into : xcommavar separated by ','

	From dictionary.columns

	Where libname='MYLIB'

		AND memname='INMACRO';
Quit;

* create the distance matrix using no restirctions on warping and Absolute

 Deviations as the distance measure;
proc tsmodel data=mylib.indat nosummary  outlog=mylib.outlog

	outobj=(of= mylib.outdist(replace=YES) );
	var &xvar;
	id date interval=month;
	require tsd;
	submit;
	declare object f(DTW);
	declare object of(OUTTSD);
	rc = f.Initialize();
	rc = f.SetTarget(&xcommavar);
	rc = f.SetOption("XWINPCT", 100,

	"YWINPCT", 100,

	"METRIC", "ABSDEV",

	"NORMALIZE", "STD",

	"TRIM", "BOTH");
	rc = f.Run();

	if rc < 0 then
		stop;
	rc = of.Collect(f);

	if rc < 0 then
		stop;
	endsubmit;
	print outlog;
run;

/* this block of code converts the distance measure to a symmetric matrix form so it can be passed

                         to Proc CLUSTER

*/
data work.have;
	set mylib.outdist;
	Distance2=cats(Distance);
	drop Distance;
run;

proc iml;
	use work.have;
	read all var {"targetSeries" "inputSeries" "Distance2"} into raw[colname=colNames];
	close work.have;
	raw=raw//(raw[,2]||raw[,1]||raw[,3]);
	uniqVec=t(unique(colvec(raw[,1:2])));

	*print uniqVec;
	cartProd=expandGrid(uniqVec,uniqVec);

	*print cartProd;
	create orig from raw[colname=colNames];
	append from raw;
	close orig;
	create cartProd from cartProd[colname=colNames];
	append from cartProd;
	close cartProd;
	submit;

proc sql;
	create table work.long as
		select               a.targetSeries
			,                          a.inputSeries
			,                          
		case 
			when a.targetSeries=a.inputSeries then 0 
			else input(b.Distance2,BEST.) 
		end 
	as Distance
		from cartProd as a
			left join orig as b on a.targetSeries=b.targetSeries and a.inputSeries=b.inputSeries;
quit;

proc transpose data=work.long out=local.wide (drop=_NAME_);
	by targetSeries;
	var Distance;
	id inputSeries;
run;

endsubmit;
quit;

proc cluster data=local.wide method=ward outtree=tree;
	id targetseries;
	var &xvar;
run;

/* The tree procedure creates the dendrogram, and then 'cuts' it at the

          nclusters=x solution. Note, different numbers of clusters

          can be tried by modifying the nclusters option

*/
proc tree data=tree nclusters=5 out=dyncluster;
	copy targetseries;
run;

/* check for orphan clusters */
proc freq data=dyncluster;
	tables cluster;
run;

/* visualize the clustered series */
* merge the cluster information into the original data;
data work.indat;
	set mylib.indat;
	drop t;
run;

proc sort data=indat;
	by date;
run;

* convert the original data into a by variable format;
proc transpose data=indat out=indatby

	name=X

	prefix=Value;
	;
	by date;
	var &xvar;
run;

proc sort data=indatby;
	by x date;
run;

data indatby;
	set indatby;
	length x $8;

	if value1 ne .;
run;

data dyncluster1;
	set dyncluster;
	drop _name_ clusname;
	rename targetseries = x;
run;

data dyncluster1;
	length x $8;
	set dyncluster1;
run;

proc sort data=dyncluster1;
	by x;
run;

data indatclus;
	merge indatby (in=a) dyncluster1;
	by x;

	if a;
run;

proc sort data=indatclus;
	by cluster date;
run;

proc timeseries data=indatclus out=indatclusout plots=(series);
	id date interval=month accumulate=average;
	var value1;
	by cluster;
run;

proc sgplot data=indatclus;
	series x=date y=value1 / group=cluster;
run;