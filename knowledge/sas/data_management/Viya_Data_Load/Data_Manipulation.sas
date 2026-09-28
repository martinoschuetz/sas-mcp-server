options msglevel=i;
cas mySession sessopts=(messagelevel=all);
caslib dataproc datasource=(srctype=path) 
	path="/gelcontent/demo/DM/data/SAMPLE";
libname libcas cas caslib="dataproc";

/* List source files */
proc casutil;
	list files incaslib="dataproc";
	quit;

	/* Load tables */
proc casutil;
	load casdata="megacorp_facts.sashdat" incaslib="dataproc" outcaslib="dataproc" 
		casout="&sysuserid._facts" copies=0 replace;
	load casdata="megacorp_proddim.sashdat" incaslib="dataproc" 
		outcaslib="dataproc" casout="&sysuserid._proddim" copies=0 replace;
	list tables incaslib="dataproc";
	quit;

	/* Table information */
proc casutil;
	contents casdata="&sysuserid._facts" incaslib="dataproc";
	contents casdata="&sysuserid._proddim" incaslib="dataproc";
	quit;

proc cas;
	table.tabledetails / name="&sysuserid._facts" caslib="dataproc" level="node";
	table.tabledetails / name="&sysuserid._proddim" caslib="dataproc" level="node";
quit;

/* Data Step Merge */
data libcas.&sysuserid._merge_ds(copies=0);
	merge libcas.&sysuserid._facts(in=a) libcas.&sysuserid._proddim;
	by ProductID;

	if a;
run;

/* Data Step by groups and first. last. notation */
data libcas.&sysuserid._dsby(copies=0 drop=expenses);
	length sum_expenses 8;
	retain sum_expenses 0;
	set libcas.&sysuserid._merge_ds(keep=Product expenses);
	by Product;

	if first.Product then
		sum_expenses=0;
	sum_expenses=sum_expenses+expenses;

	if last.Product then
		output;
run;

/* Multi-threading behavior */
data libcas.&sysuserid._dsmulti(copies=0 drop=expenses);
	length max_expenses 8;
	retain max_expenses 0;
	set libcas.&sysuserid._merge_ds(keep=expenses) end=last;

	if expenses>max_expenses then
		max_expenses=expenses;

	if last then
		output;
run;

/* Single-threading behavior */
data libcas.&sysuserid._dssingle(copies=0 drop=expenses) / single=yes;
	length max_expenses 8;
	retain max_expenses 0;
	set libcas.&sysuserid._merge_ds(keep=expenses) end=last;

	if expenses>max_expenses then
		max_expenses=expenses;

	if last then
		output;
run;

/* DS2 Merge */
proc cas;
	session mySession;
	ds2.runDS2 / program="thread join_th / overwrite=yes ;

      method run() ;

         merge dataproc.&sysuserid._facts(in=a) dataproc.&sysuserid._proddim ;

         by ProductID ;

         if a ;

      end ;

   endthread ;

   data dataproc.&sysuserid._merge_ds2(copies=0) / overwrite=yes ;

      dcl thread dataproc.join_th t ;

      method run() ;

         set from t ;

      end ;

   enddata ;

   ";
quit;

/* FedSQL Join and Aggregation */
proc fedsql sessref=mySession _method;
	create table dataproc.&sysuserid._join_agg_fed {options replace=true 
		replication=0} as select Date, Product, sum(Revenue) as Revenue from 
		dataproc.&sysuserid._facts as a left join dataproc.&sysuserid._proddim as b 
		on a.ProductID=b.ProductID group by Date, Product;
	quit;

	/* Table Transposition */
proc cas;
	session mySession;
	action transpose.transpose / table={caslib="dataproc", 
		name="&sysuserid._join_agg_fed", groupby={"Date"}} transpose={"revenue"} 
		id={"Product"} casOut={caslib="dataproc", name="&sysuserid._agg_tr", 
		replace=true, replication=0};
quit;

/* Create format */
proc format casfmtlib="userformats1";
	value &sysuserid._myDayName 1="Sunday" 2="Monday" 3="Tuesday" 4="Wednesday" 
		5="Thursday" 6="Friday" 7="Saturday";
run;

/* List formats */
cas mySession listfmtsearch;
cas mySession listformats members;

/* Apply format */
data libcas.&sysuserid._facts_fmt(copies=0);
	length DayName $ 9;
	set libcas.&sysuserid._facts(keep=Date DayOfWeek FacilityId FacilityCity 
		ProductId Revenue Profit Expenses);
	DayName=put(DayOfWeek, &sysuserid._myDayName.);
run;

/* Pass-through */
caslib pg datasource=(srctype="postgres", authenticationDomain="PGAuth", 
	server="sasdb.race.sas.com", database="dvdrental", schema="public");

proc fedsql sessref=mySession _method;
	create table dataproc.&sysuserid._fed_pt{options replace=true replication=0} 
		as select customer.first_name, customer.last_name, address.address from 
		pg."customer" as customer, pg."address" as address where 
		customer.address_id=address.address_id;
	quit;

	/* Data quality functions */
data libcas.&sysuserid._baseball_dq(copies=0);
	set sashelp.baseball;
run;

data libcas.&sysuserid._baseball_dq(copies=0);
	length gender $1 mcName varchar(100);
	set libcas.&sysuserid._baseball_dq;
	gender=dqGender(name, 'Name', 'ENUSA');
	mcName=dqMatch(name, 'NAME', 95, 'ENUSA');
run;

/* Profile */
proc cas;
	dataDiscovery.profile / algorithm="PRIMARY" table={caslib="dataproc" 
		name="&sysuserid._merge_ds"} columns={"ProductBrand", "ProductLine", 
		"Product", "ProductDescription"} cutoff=20 frequencies=10 outliers=5 
		casOut={caslib="dataproc" name="&sysuserid._dq_profiled" replace=true 
		replication=0};
quit;

cas mySession terminate;