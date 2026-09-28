cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" metrics=true);

caslib _all_ assign;
caslib _all_ list;

/*
%macro drop_table(caslib=,ds=);
	%if %sysfunc(exist(&caslib..&ds.)) %then %do;
		proc casutil;
			droptable incaslib="&caslib." casdata="&ds.";
    	run; quit;
	%end;
%mend drop_table;
*/

/* Unload all demo data from CAS */

proc casutil; droptable incaslib="casdata" casdata="events_lodz" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="sensor_lodz2" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="MAINTENANCE_COSTS_LODZ" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="UNPLANNED_BODY_LODZ" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="winequality" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="winedemandwithattributes" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="winequality_reviews" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="engstop" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="wineDemand_attributes" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="wineDemand" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="hmeq_perf_q1" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_perf_q2" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_perf_q3" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_perf_q4" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="hmeq_project_input" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_project_output" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_test" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="hmeq_train" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="simulated_row7000_col1500_cat" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="simulated_row7000_col1500_num" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="simulated_row7000_col1500" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="autoforum_text_problem_class" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="grmnstop" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="automotive_diskussionen" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="automotive_terme" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="automotive_autoren" quiet; run; 
proc casutil; droptable incaslib="casdata" casdata="automotive_texte" quiet; run; 

proc casutil; droptable incaslib="casdata" casdata="kaggle_enron_emails" quiet; run; 

cas mySession terminate;
