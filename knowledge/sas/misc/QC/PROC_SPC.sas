/* Copyright (c) 2024 by SAS Institute Inc., Cary, NC USA 27513 */

/* Generate AllProcess first by using spcgs.sas */ 

cas mysession;

libname public cas caslib="Public";
libname casuser cas caslib="Casuser";

proc datasets lib=public nodetails nolist;
	delete SPC_AllProcesses;
run;

data public.SPC_AllProcesses(promote=yes);
   set AllProcesses;
run;

/* Seperation of control charts.
	Mean and range charts for less than 10 observations per subgroup
	Mean and sigma chart for mor ethan 10 observations. */
proc delete lib=casuser data=max_counts counts_process; run;
proc fedsql sessref=mysession;
    create table casuser.max_counts as 
    select processname, subgroupname, subgroup, count(*) from public.SPC_AllProcesses
    group by processname, subgroupname, subgroup;

	create table casuser.counts_process as
	select processname, min(count), max(count) from casuser.max_counts
	group by processname;
quit;

ods output XRChartExceptionSummary=SPC_XR_Alert_Table;
proc spc data=public.SPC_AllProcesses ;
   xrchart / tests=1 to 8 testnstd
	outtable=casuser.SPC_Table
	outlimits=casuser.SPC_AllLimits;;
run;
ods output close;

proc casutil;
	droptable incaslib="PUBLIC" casdata="SPC_XR_Alert_Table" quiet;
	droptable incaslib="PUBLIC" casdata="SPC_Table" quiet;
	droptable incaslib="PUBLIC" casdata="SPC_AllLimits" quiet;
	load data=work.SPC_XR_Alert_Table outcaslib="PUBLIC" casout="SPC_XR_Alert_Table" promote compress;
	promote incaslib="CASUSER" casdata="SPC_Table" outcaslib="PUBLIC" casout="SPC_Table";
	promote incaslib="CASUSER" casdata="SPC_AllLimits" outcaslib="PUBLIC" casout="SPC_AllLimits";
	save incaslib="PUBLIC" casdata="SPC_XR_Alert_Table" outcaslib="PUBLIC" casout="SPC_XR_Alert_Table" compress replace;
	save incaslib="PUBLIC" casdata="SPC_Table" outcaslib="PUBLIC" casout="SPC_Table" compress replace;
	save incaslib="PUBLIC" casdata="SPC_AllLimits" outcaslib="PUBLIC" casout="SPC_AllLimits" compress replace;
quit;

cas mysession terminate;
