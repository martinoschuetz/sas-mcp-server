/* Copyright (c) 2024 by SAS Institute Inc., Cary, NC USA 27513 */

/*  
	Basic Flow of the SVDD CAF Training code.
	- Loop SVDD training over all selected assets.
	- Training the SVDD model per asset on the stable period.
	- Score per asset on all historically available data.
	- Build one scoring table for all assets / device_Id (can be used for the time series chart)
	- Loop over all assets and build a GB classification model based on the svdd distance.
	- Write a global influcence table per asset
	- Use proc score with option "treeshap 1" to generated the local influences per asset and observation.
	- Build corresponding tables for visualization. 
	
	ToDo: Performance tuning by moving everything to cas computation: transpose, fedsql instead of sql, display instead of ods output, ... 
*/
 OPTION SPOOL;
/* Connect to the postgres metadata and retrieve */
%qas_getconnections(g_cas=?g_cas, g_metadata=?g_metadata);
%anl_getanalysisattributes(?analysisID);

%global G_INSTANCEID;
proc sql noprint;
	select analysis_ins_id into :G_INSTANCEID
	from mfgapp.analysis_ins_step
	where analysis_ins_step_id="&G_ANALYSISID";
quit;
%put &=G_INSTANCEID.;

/* we now have access to vars like this:         */
/*
GLOBAL G_INSTANCEID 3f4456be-2148-49ff-a32e-fb823799ccd5
GLOBAL G_ANALYSISID 3b893d75-3f68-4b37-adde-cb92046517d6
GLOBAL G_ANALYSISTYPE SVDD
GLOBAL G_CASANLOUT QASAnlOut
GLOBAL G_CASLIB QASMartStore
GLOBAL G_CASSESSIONID a9a0428b-e66b-bf45-8fe4-4cce651b93ce
GLOBAL G_CASUSER atbroo
GLOBAL G_DATASELECTIONID 0f7abfb2-878e-4541-b3c7-6e948f0ca8f4
GLOBAL G_INPUTVARS CAM.50F-012A.MV,CAM.50MI-032.PV,CAM.50RRU-011.PV,CAM.50PZ-001.PV,CAM.23PDW-001.MV,CAM.23PDW-001.PV
GLOBAL G_INSTANCE_NAME SVDD 1
GLOBAL G_INSTANCE_NM E0DCBD01
GLOBAL G_SM_ASSET_VARIABLE ASSET4.CAM.PV
GLOBAL G_STABLE_PERIOD 01DEC12:23:59:55-31DEC12:11:59:55
GLOBAL G_TARGETVAR CAM.23PDW-001.PV
*/
/* Additional metadata is available in this     */
/* temporary caslib:                            */
/* MFGAPP                                       */
/* Data has been stored for us in this table:   */
/* QASANLOUT.SVDD_TRANSPOSE_E0DCBD01       */

/************************************************/
/* HERE WE WANT TO DO THE REAL SVDD STUFF       */
/************************************************/

/*%let G_ANALYSISTYPE=SVDD;*/
%let G_ANALYSISTYPE=SVDD;
%let g_casanlout=QASAnlOut;

CAS mySession SESSOPTS=(CASLIB=&g_casanlout. TIMEOUT=99);
libname qasanl CAS datalimit=all sessref=mySession;

%put	&=G_INSTANCEID;
%put	&=G_ANALYSISID;
%put	&=G_ANALYSISTYPE;
%put	&=G_CASANLOUT;
%put	&=G_CASLIB;
%put	&=G_CASSESSIONID;
%put	&=G_CASUSER;
%put	&=G_DATASELECTIONID;
%put	&=G_INPUTVARS;
%put	&=G_INSTANCE_NAME;
%put	&=G_INSTANCE_NM;
%put	&=G_SM_ASSET_VARIABLE;
%put	&=G_STABLE_PERIOD;
%put	&=G_TARGETVAR;

%global G_INPUTVARS_MOD;
%let G_INPUTVARS_MOD=%sysfunc(tranwrd(%bquote(&G_INPUTVARS.), %str(,), %str()));
%put &=G_INPUTVARS_MOD.;

/* Delete VA scoring table if it exists from a prior run */
/* GERMSZ: Scoring of new data should go into the next step of the analysis. */
/*
proc cas;
	table.tableExists result=r / caslib="&G_CASANLOUT" 	name="&G_ANALYSISTYPE._SCOREVA_&g_instance_nm";
	if r.exists then table.dropTable / caslib="&G_CASANLOUT" name="&G_ANALYSISTYPE._SCOREVA_&g_instance_nm";
quit;
*/

%put &=G_STABLE_PERIOD.;
%global /* G_STABLESTART G_STABLEEND*/ G_TIME_FILTER;

%macro generate_time_filter;

  %local i G_STABLE_PART G_STABLESTART G_STABLEEND;
  %let i = 1;
  %let G_TIME_FILTER =;

  %let G_STABLE_PERIOD = %sysfunc(strip(&G_STABLE_PERIOD.));
  %let G_STABLE_PART = %scan(%nrbquote(&G_STABLE_PERIOD.), &i., ','); 

  %do %until (%length(&G_STABLE_PART.) = 0); 
    %let G_STABLESTART = %scan(%nrbquote(&G_STABLE_PART.), 1, '-');
    %let G_STABLEEND = %scan(%nrbquote(&G_STABLE_PART.), 2, '-');

    %if &i. eq 1 %then %do;
      %let G_TIME_FILTER = (DATETIME ge "&G_STABLESTART."dt and DATETIME le "&G_STABLEEND."dt);
    %end;
    %else %do;
      %let G_TIME_FILTER = &G_TIME_FILTER. or (DATETIME ge "&G_STABLESTART."dt and DATETIME le "&G_STABLEEND."dt);
    %end;

    %put &=i. &=G_STABLE_PART. &=G_STABLESTART. &=G_STABLEEND.;
  
    %let i = %eval(&i. + 1);
    %let G_STABLE_PART = %scan(%nrbquote(&G_STABLE_PERIOD.), &i., ','); 
  %end;
  %let G_TIME_FILTER=(&G_TIME_FILTER.);
%mend generate_time_filter;
%generate_time_filter;
%put &=G_TIME_FILTER.;

/*
%let G_STABLESTART=%sysfunc(scan(&G_STABLE_PERIOD, 1, '-'));
%let G_STABLEEND=%sysfunc(scan(&G_STABLE_PERIOD, 2, '-'));
*/
/*
%let G_STABLESTART=01JUL23:00:00:01;
%let G_STABLEEND=21DEC23:23:59:59;

%put &=G_STABLESTART &=G_STABLEEND;
*/

%put &=G_SM_ASSET_VARIABLE.;

/* Substitute special characters in asset names by '_'. */
%let special_chars = %str(!%"#$&%'()*+,-./:;<=>?@[]^_`{|}~% );
%let replace_chars = %sysfunc(repeat(_,%length(&special_chars.)));

%macro train_all_assets;
	%local i G_ASSET_VARIABLE;
	%let i=1;

	%do %while (%scan(%nrbquote(&G_SM_ASSET_VARIABLE), &i., %str(,)) ne);
	
		%let G_ASSET_VARIABLE=%scan(%nrbquote(&G_SM_ASSET_VARIABLE), &i., %str(,));
		%put Training Asset (&i.): &G_ASSET_VARIABLE;
/*		%let G_ASSET_VARIABLE_NM=%sysfunc(tranwrd(&G_ASSET_VARIABLE,%str(.),%str(_)));*/
		%let G_ASSET_VARIABLE_NM=%sysfunc(translate(%sysfunc(strip(&G_ASSET_VARIABLE.)), &replace_chars., &special_chars.));
		%put &=G_ASSET_VARIABLE_NM.;

		/* Delete all tables which will be generated during training and must be persisted for scoring. */
		proc casutil incaslib="&g_casanlout.";
			droptable casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST" quiet;
			droptable casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2" quiet;
			droptable casdata="&G_ANALYSISTYPE._&g_instance_nm._gimportance" quiet;
			droptable casdata="&G_ANALYSISTYPE._&g_instance_nm._TS_trans" quiet;
			droptable casdata="&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T" quiet;
		quit;

		/* 	Create performance table for all SVDD and GB models. This will be overwritten in each training step.
		Will be attributed to the output tables.
		Should be persisted for the scoring step and further calls of the same SVDD custom analysis. */
		data performance;
			attrib instance label="Custom Analysis instance name" format=$10.;
			attrib pam_asset_id label="Asset ID" format=$32.;
			attrib R2_SVDD label="&G_ANALYSISTYPE. R2 SVDD value" format=best.;
			if R2_SVDD ne .;
		run;

		/* Perform SVDD training per Asset */
		ods exclude where=(_name_ ne "TrainingResults");
		ods output TrainingResults=TrainingResults;
		proc svdd data=qasanl.&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm
/*			(where=(PAM_ASSET_ID="&G_ASSET_VARIABLE." and DATETIME ge "&G_STABLESTART."dt and DATETIME le "&G_STABLEEND."dt));*/
			(where=(PAM_ASSET_ID="&G_ASSET_VARIABLE." and &G_TIME_FILTER.));
			id PAM_ASSET_ID DATETIME &G_INPUTVARS_MOD.;
			input &G_INPUTVARS_MOD. /level=interval;
			kernel rbf / bw=mean2;
			savestate rstore=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST;
		run;
		ods exclude none;

		/* Persist SVDD ASTORE for later scoring. */
		proc casutil outcaslib="&g_casanlout.";
			promote incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST" casout="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST";
			save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST" casout="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST" replace compress;
		quit;

		/* Store the R2 SVDD value from training per asset */
		data _null_;
			set TrainingResults;
			if upcase(strip(RowId)) eq "THRESH" then call symput("R2", value);
		run;

		proc sql noprint;
			insert into performance
			values ("&g_instance_nm.", "&G_ASSET_VARIABLE", &R2.);
		quit;

		/* Score SVDD model on complete available data set, i.e. not only the stable region for importance calculation via GB. */
		ods exclude all;
		proc astore;
			score data=qasanl.&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm.(where=(PAM_ASSET_ID="&G_ASSET_VARIABLE.")) 
				rstore=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST
				out=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO;
		quit;
		ods exclude none;

		/* 	Build GB model on the outlier classification of the SVDD on the complete training set per asset.
		Main output will be the global variable importance and the model R2. */
		ods exclude where=(_name_ ne "VariableImportance");
		ods output VariableImportance=VariableImportance;

		proc gradboost data=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO;
			id PAM_ASSET_ID DATETIME &G_INPUTVARS_MOD. _SVDDDISTANCE_ _SVDDSCORE_;

			crossvalidation kfold=5;
			/*autotune kfold=5 maxiter=10 popsize=50 searchmethod=ga useparameters=standard;*/
			input &G_INPUTVARS_MOD. /level=interval;
			target _SVDDDISTANCE_ / level=interval;
			savestate rstore=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2;
		run;
		ods exclude none;

		/* Persist GB ASTORE for later scoring. */
		proc casutil outcaslib="&g_casanlout.";
			promote incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2" casout="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2";
			save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2" casout="&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2" replace compress;
		quit;

		data VariableImportance;
			attrib instance label="Custom Analysis instance name" format=$10.;
			attrib pam_asset_id label="Asset ID" format=$32.;
			set VariableImportance;
			instance="&g_instance_nm.";
			pam_asset_id="&G_ASSET_VARIABLE.";
		run;

		%if &i.=1 %then %do;
			data &G_ANALYSISTYPE._&g_instance_nm._gimportance;
				set VariableImportance;
			run;
		%end;
		%else %do;
			proc append base=&G_ANALYSISTYPE._&g_instance_nm._gimportance data=VariableImportance; run;
		%end;

		/* 	Score GB model on SVDD scored complete available data set per asset, i.e. not only the stable region.
			This will be used to compute the GB performance and build the Shapely Values.*/
		ods exclude all;
		proc astore;
			setoption TREESHAP 1;
			score data=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO
			rstore=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._AST2
			out=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO2;
		quit;
		ods exclude none;
		
		/*	Compute performance statistics of GB model, especially R2. */
		ods exclude where=(_name_ ne "FitStat");
		ods output FitStat=FitStatistics;
		proc assess data=qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO2;
			var P__SVDDDISTANCE_;
			target _SVDDDISTANCE_ / level=interval;
		run;
		ods output clear;

		data performance;
			merge performance FitStatistics;
		run;

		/* In the first iteration generate the first performance and final timeseries base tables by copying, otherwise append. */
		%if &i.=1 %then %do;
			data &G_ANALYSISTYPE._&g_instance_nm._performance;
				set performance;
			run;

			data qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS;
				set qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO2;
				label datetime="DATETIME";
			run;
		%end;
		%else %do;
			proc append base=&G_ANALYSISTYPE._&g_instance_nm._performance data=performance;	run;

			/* Build output time series table by appending asset individual tables */
			data qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS;
				set qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS 
					qasanl.&G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO2;
			run;
		%end;
		
		/* Local clean-up */
		proc datasets lib=qasanl nodetails nolist;
			delete &G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO &G_ANALYSISTYPE._&G_ASSET_VARIABLE_NM._&g_instance_nm._SCO2;
		run;	
		
		%let i=%eval(&i + 1);

	%end; /* End Asset Loop */

	/* Join global performance measures with svdd and gb metrics, load to qasanl and promote. */
	proc sql noprint nowarnrecurs;
		create table work.&G_ANALYSISTYPE._&g_instance_nm._gimportance(drop=instance_p pam_asset_id_p) as
		select t1.*, t2.* from
		work.&G_ANALYSISTYPE._&g_instance_nm._gimportance t1
		left join work.&G_ANALYSISTYPE._&g_instance_nm._performance(rename=(instance=instance_p pam_asset_id=pam_asset_id_p)) t2
		on (t1.instance=t2.instance_p and t1.pam_asset_id eq t2.pam_asset_id_p);
	quit;

	/* Persist global performance Table for the scoring step */
	proc casutil outcaslib="&g_casanlout.";
		load data=work.&G_ANALYSISTYPE._&g_instance_nm._gimportance	casout="&G_ANALYSISTYPE._&g_instance_nm._gimportance" promote compress;
		save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&g_instance_nm._gimportance" casout="&G_ANALYSISTYPE._&g_instance_nm._gimportance" replace compress;
	quit;

	/* Build transposed table for global and local explainer charts. */
	proc sort data=qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS
		out=&G_ANALYSISTYPE._&g_instance_nm._TS;
		by PAM_ASSET_ID DATETIME _SVDDDISTANCE_;
	run;

	proc transpose data=&G_ANALYSISTYPE._&g_instance_nm._TS(keep=PAM_ASSET_ID
		DATETIME &G_INPUTVARS_MOD. _SVDDDISTANCE_) out=qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS_trans(rename=(col1=value));
		var &G_INPUTVARS_MOD.;
		by PAM_ASSET_ID DATETIME _SVDDDISTANCE_;
	run;

	/* Parallel CAS version not working */
	/*
	%let hlp=PAM_ASSET_ID DATETIME &G_INPUTVARS_MOD. _SVDDDISTANCE_;
	%put &=hlp.;
	%let hlp2="%sysfunc(tranwrd(%bquote(&hlp.), %str( ), %str(", ")))";
	%put &=hlp2.;
	*/
	/* Create unique identifier necessary for cas proc transpose*/
	/*
	proc cas;
	textManagement.generateIds /
	table={caslib="&g_casanlout.", name="&G_ANALYSISTYPE._&g_instance_nm._TS", vars={&hlp2.}},
	casOut={name="_TMP", caslib="&g_casanlout.",	replace=TRUE}, id="Id";
	run;
	quit;
	
	proc transpose data=qasanl._tmp out=qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS_trans;
	id id;
	var &G_INPUTVARS_MOD.;
	by PAM_ASSET_ID DATETIME _SVDDDISTANCE_;
	run;
	*/
	
	/* Build control chart information for the _SVDDDISTANCE_ time series */
	/*
	Western Electric Rules (Original)
	Rule 1: One point is more than 3 standard deviations from the mean (either above or below).			- Extreme outlier	
	Rule 2: Nine (or more) points in a row are on the same side of the mean. 							- Shift in the process mean
	Rule 3: Six (or more) points in a row are continually increasing (or decreasing).					- Trend
	Rule 4: Fourteen (or more) points in a row alternate in direction, increasing then decreasing.		- Systematic variation

	Nelson Rules (Additional)
	Rule 5: Two out of three consecutive points are more than 2 standard deviations from the mean (on the same side).	- Smaller shift in the mean
	Rule 6: Four out of five consecutive points are more than 1 standard deviation from the mean (on the same side).	- Process instability
	Rule 7: Fifteen points in a row are all within 1 standard deviation of the mean (either above or below).			- Reduced variation
	Rule 8: Eight points in a row exist with none within 1 standard deviation of the mean 
			and the points are in both directions from the mean.														- Stratification (lack of randomness)
	*/
	
	/* Create artifical columns for subgroup name and subgroup value such that proc spc can work. */
	data qasanl._tmp_spc;
		set qasanl.&G_ANALYSISTYPE._&g_instance_nm._TS(keep=PAM_ASSET_ID DATETIME _SVDDDISTANCE_);
		subgroupname = "Group 1";
		subgroup = 1;
	run;
	
	ods output IRChartExceptionSummary=SPC_Alert_Table;
	proc spc data=qasanl._tmp_spc
		processname=PAM_ASSET_ID subgroupname=subgroupname subgroupvalue=DATETIME processvalue=_SVDDDISTANCE_;
		irchart / tests=1 to 8
		outtable=qasanl.SPC_Table
		outlimits=qasanl.AllLimits;
	run;
	ods output close;

	data qasanl.SPC_Table;
		set qasanl.SPC_Table(rename=(DATETIME=DATETIME_SPC));
	run;

	proc fedsql sessref=mySession noprint;
		drop table &g_casanlout.._tmp force;
		create table &g_casanlout.._tmp as
		select t1.*, t2.* from &g_casanlout..&G_ANALYSISTYPE._&g_instance_nm._TS_trans t1 
			left join &g_casanlout..SPC_Table t2
			on (t1.PAM_ASSET_ID=t2._var_ and t1.datetime=t2.datetime_spc);
	quit;
	
	proc cas;
  		table.altertable / caslib="&g_casanlout.", name="_tmp", drop={"DATETIME_SPC", "_var_"};
	quit;
	
	/* Persist transposed and enriched time series table for visualization. */
	proc casutil outcaslib="&g_casanlout.";
		droptable incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&g_instance_nm._TS_trans" quiet;
		promote incaslib="&g_casanlout." casdata="_tmp" casout="&G_ANALYSISTYPE._&g_instance_nm._TS_trans";
		save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&g_instance_nm._TS_trans" casout="&G_ANALYSISTYPE._&g_instance_nm._TS_trans" replace compress;
	quit;

	/* From time series table build transposed Shapely table for explainer visualization */
	proc transpose data=&G_ANALYSISTYPE._&g_instance_nm._TS(keep=PAM_ASSET_ID DATETIME P__SVDDDISTANCE_ _SVDDDISTANCE_ S__:) 
		out=work.&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T;
		var S__:; 
		by PAM_ASSET_ID DATETIME _SVDDDISTANCE_ P__SVDDDISTANCE_;
	run;

	data work.&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T;
		set work.&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T(rename=(col1=shapely));
		attrib vname	label="Name of Variable";
		attrib shapely  label="Shapely Value";
		attrib ashapely label="Absolute Shapely Value";
		/* Original variable name necessary for explainer matching */
		vname = substr(_name_,17);
		ashapely = abs(shapely);

	run;

	proc casutil outcaslib="&g_casanlout.";
		load data=work.&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T casout="&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T" promote;
		save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T" casout="&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T" replace compress;
	quit;
	
	/* Cleaning section */
	
	proc datasets lib=work kill nodetails nolist; run;
	proc datasets lib=qasanl nodetails nolist; 
		delete alllimits spc_table;
	run;
	
%mend train_all_assets;

%train_all_assets;

proc printto; run;


/* Store tables to use for populating step 3 UI */
/* 
CAS mySession SESSOPTS=(CASLIB=&g_casanlout. TIMEOUT=99);
libname qasanl CAS datalimit=all sessref=mySession;
*/
data work.&G_ANALYSISTYPE._ASSET_&g_instance_nm;
	set qasanl.&G_ANALYSISTYPE._ASSETS_&g_instance_nm (where=(PAM_ASSET_ID="&g_sm_asset_variable"));
run;
proc casutil outcaslib="&g_casanlout.";
	droptable casdata="&G_ANALYSISTYPE._ASSET_&g_instance_nm" quiet;
	load data=work.&G_ANALYSISTYPE._ASSET_&g_instance_nm casout="&G_ANALYSISTYPE._ASSET_&g_instance_nm" promote;
	save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._ASSET_&g_instance_nm" casout="&G_ANALYSISTYPE._ASSET_&g_instance_nm" replace compress;
quit;
%put &=g_targetvar.;
data work.&G_ANALYSISTYPE._TAG_&g_instance_nm;
	set qasanl.&G_ANALYSISTYPE._TAGS_&g_instance_nm(where=(TAG_COLUMN_NM="&g_targetvar."));
	call symputx('tagcolnm',TAG_COLUMN_NM);
run;

proc casutil outcaslib="&g_casanlout.";
	droptable casdata="&G_ANALYSISTYPE._TAG_&g_instance_nm" quiet;
	load data=work.&G_ANALYSISTYPE._TAG_&g_instance_nm casout="&G_ANALYSISTYPE._TAG_&g_instance_nm" promote;
	save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._TAG_&g_instance_nm" casout="&G_ANALYSISTYPE._TAG_&g_instance_nm" replace compress;
quit;
data work.&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm(keep=PAM_ASSET_ID DATETIME &g_targetvar. /* &tagcolnm. */);
	set qasanl.&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm (where=(PAM_ASSET_ID="&g_sm_asset_variable"));
run;
proc casutil outcaslib="&g_casanlout.";
	droptable casdata="&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm" quiet;
	load data=work.&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm casout="&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm" promote;
	save incaslib="&g_casanlout." casdata="&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm" casout="&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm" replace compress;
quit;

	

/* Call API to update metadata with variable values that the VA report will need */
filename json_in temp;
data _null_;
	file json_in;
	put '{ "analysisStepOutputParams": [ ';
	put ' { "outputname": "TS_TRANS_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._&g_instance_nm._TS_TRANS" '"} ,';
	put ' { "outputname": "GIMPORTANCE_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._&g_instance_nm._GIMPORTANCE" '"} ,';
	put ' { "outputname": "TS_SHA_T_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._&g_instance_nm._TS_SHA_T" '"} ,';
	put ' { "outputname": "SEL_ASSET_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._ASSET_&g_instance_nm" '"} ,';
	put ' { "outputname": "SEL_TAG_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._TAG_&g_instance_nm" '"} ,';
	put ' { "outputname": "FIL_TRANSPOSE_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._FILTRANSPOSE_&g_instance_nm" '"} ';
	put ' ]';
	put '}';
run;

%let SERVICE_TEMPLATE=%SYSGET(SAS_URL_SERVICE_TEMPLATE);
%let BASE_URI_CREDENTIALS=%sysfunc(TRANWRD(&SERVICE_TEMPLATE, @k8s.service.name@, sas-iot-analysis));

filename resp temp;
proc http method="POST"
	url="&BASE_URI_CREDENTIALS./iotAnalysis/analyses/&G_INSTANCEID./steps/&G_ANALYSISID./outputParams"
	OAUTH_BEARER=SAS_SERVICES ct="application/json"
	in=json_in out=resp;
quit;
