options cashost="dach-viya-smp.sas.com";
options CASPORT=5570;
/*options casuser=sasdemo01;*/

cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" metrics=true);

libname sasdemo 	"/opt/data/demodata";
libname winedemo	"/opt/data/wine";
libname mm_hmeq		"/opt/data/mm_hmeq/Data";

caslib _all_ assign;
caslib _all_ list;

%macro prepare_demo_data(baselib=,caslib=,ds=);
	%if not %sysfunc(exist(&caslib..&ds.)) %then %do;
		proc casutil;
			load data=&baselib..&ds. outcaslib="&caslib." casout="&ds." promote;
    		save casdata="&ds." incaslib="&caslib." outcaslib="&caslib." replace;
    	run; quit;
	%end;
%mend prepare_demo_data;

/* Create CAS Publish Destination for MM */
/*
%let servernm=http://dach-viya-smp.sas.com;
%let userID=sasdemo01;
%let password=SASpw1;

%mm_get_token(
    baseURL=&servernm,
    user=&userID,
    pw=&password,
    tokenname=myTokenName
);

%let defname=myDestinationName;
%mm_definepublishdestination(
    baseURL=%str(&servernm),
    definitionname=&defName,
    casservername=cas-shared-default,
    caslib=Models,
    modeltable=mm_model_table,
    exttype=cas,
    token=%myTokenName
);
*/

/* Load APA Data to CAS */
/* APA Demo Data for Data Preparation */
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=events_lodz);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=sensor_lodz2);
/* APA Demo Data for Exploration and Modeling */
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=MAINTENANCE_COSTS_LODZ);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=UNPLANNED_BODY_LODZ);

/* Load Wine Data to CAS */
/* EDA and Predictive Part and Reporting */
%prepare_demo_data(baselib=winedemo,caslib=casdata,ds=winequality);
%prepare_demo_data(baselib=winedemo,caslib=casdata,ds=winedemandwithattributes);
/* Text Analytics data */
%prepare_demo_data(baselib=winedemo,caslib=casdata,ds=winequality_reviews);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=engstop);
/* Forecasting Part */
%prepare_demo_data(baselib=winedemo,caslib=casdata,ds=wineDemand_attributes);
%prepare_demo_data(baselib=winedemo,caslib=casdata,ds=wineDemand);

/* Load HMEQ data for Model Lifecycle Management */
%prepare_demo_data(baselib=mm_hmeq,caslib=public,ds=hmeqperf_1_q1);
%prepare_demo_data(baselib=mm_hmeq,caslib=public,ds=hmeqperf_2_q2);
%prepare_demo_data(baselib=mm_hmeq,caslib=public,ds=hmeqperf_3_q3);
%prepare_demo_data(baselib=mm_hmeq,caslib=public,ds=hmeqperf_4_q4);

%prepare_demo_data(baselib=mm_hmeq,caslib=casdata,ds=hmeq_project_input);
%prepare_demo_data(baselib=mm_hmeq,caslib=casdata,ds=hmeq_project_output);
%prepare_demo_data(baselib=mm_hmeq,caslib=casdata,ds=hmeq_test);
%prepare_demo_data(baselib=mm_hmeq,caslib=casdata,ds=hmeq_train);

/* Load HMEQ data for Model Lifecycle Management */
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=simulated_row7000_col1500_cat);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=simulated_row7000_col1500_num);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=simulated_row7000_col1500);

/* Auto Forums for Text Analytics */
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=autoforum_text_problem_class);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=grmnstop);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=automotive_diskussionen);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=automotive_terme);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=automotive_autoren);
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=automotive_texte);

/* Enron Mails for Text Analytics */
%prepare_demo_data(baselib=sasdemo,caslib=casdata,ds=kaggle_enron_emails);

cas mySession terminate;

