/* Kerberized LASR Load */
/*	The code starts with connecting to the remote VA host: */
options
	metaserver="<servername>"
	metaport=8561
	metaprotocol="bridge"
	metauser="<SAS username>"
	metapass="<password>";
%let node=<va-host> 7551;
options comamid=tcp remote=node;
signon node user=<VA user, like lasradm> password="{SAS002}encoded pw";

/*Then we define the variables like input table, output table, remote libraries and whatnot:*/
%syslput _input=&_input;
%syslput outtable=<table_name>;
%syslput lasrFolder="<SAS folder>";
%syslput lasrLib=VALIBLA;
%syslput lasrLibFolder="/Products/SAS Visual Analytics Administrator/Visual Analytics LASR";
%syslput hadoopFolder="<SAS folder>";
%syslput tableDescr=&outtable;
%syslput hadoopLibFolder="/Products/SAS Visual Analytics High-Performance Configuration/Visual Analytics HDFS";
%syslput hadoopLib=HPS;
%syslput hadoopPath="/hps";

/*Finally the rsubmit itself:*/
rsubmit;
	options set=GRIDINSTALLLOC="<TKGrid install location>";
	options set=GRIDHOST="<VA host>";
	libname &lasrLib. SASIOLA port=10010 tag="&hadoopLib";
	libname &hadoopLib SASHDAT path=&hadoopPath;

	/*The rest of the code looks like this and is pretty self-explanatory:*/
	proc datasets library=&lasrLib;
		delete &outtable;
	run;

	proc datasets library=&hadoopLib;
		delete &outtable;
	run;

	/* upload in Hadoop */
	proc upload data=&_input out=&hadoopLib..&outtable(label="&tableDescr.");
	run;

	/* save in LASR from Hadoop */
	proc lasr port=10010 data=&hadoopLib..&outtable add noclass
		signer="<SASLASRAuthorization link>";
		performance host="<VA host>";
	run;

	/* Register metadata in LASR and Hadoop */
	proc metalib;
		omr (library=&lasrLibFolder);
		folder=&lasrFolder;
		select=("&outtable");
	run;

	proc metalib;
		omr (library=&hadoopLibFolder REPNAME="Foundation");
		folder=&hadoopFolder;
		select=("&outtable");
	run;

endrsubmit;
signoff;