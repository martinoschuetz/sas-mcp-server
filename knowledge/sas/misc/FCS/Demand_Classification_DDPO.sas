/* Demand Classification and Grouping:
http://support.sas.com/documentation/onlinedoc/faw/5.3/en/PDF/dclug.pdf
*/

/* Demand Classification Wrapper */

/*Input Parameters for Hierarchy Configuration
The following input parameters are supported for hierarchy configuration:

Indata_Table 	 - Specifies the input data.
Demand_Var 		 - This variable records the demand. It contains character values.
Time_Id_Var 	 - This variable represents the time ID. It contains character values.
Class_Input_Vars - 	Input variables with numeric values, which indicate events.
			Observations with input variables that are not equal to 0 are removed in the seasonality test.
Hier_By_Vars 	 - BY variables in a specific order, which represent the hierarchy.

Input Parameters for Process Configuration
The following input parameters are supported for process configuration:
Process_Lib		 - Specifies the library for processing temporary data and output. The default value is work.
Use_Package		 - Flag that indicates whether the Time Series Analysis (TSA) package for PROC TIMEDATA should be used.
				   Possible values are 0 or 1. Default value is 0.
				   Note: Using this package might enhance performance.
				   However, it requires the second maintenance release or later of SAS 9.4.
Need_Sort		 - Flag that specifies whether the Indata_Table needs to be sorted by all BY variables that identify Class_Low level.
				   Possible values are 0 or 1. Default value is 1.
Class_Process_By_Var - Variables that are used for BY processing.
Class_Low_By_Var	 - One BY variable in the hierarchy of BY variables. It represents the Class_Low level.
					   It defines the lowest level at which the data should be aggregated and analyzed.
Class_High_By_Var	 - One BY variable in the hierarchy of BY variables. It is either at or before the Class_Low_Level
					   variable in the ordered list of BY variables, which are used to build a hierarchy.
					   It is the highest level of the data in the hierarchy that is used for demand classification, clustering, and volume grouping.
					   It is the recommended level with strong seasonality signals and sufficient volume.
Class_Time_Interval	 - Specifies the frequency of the accumulated time series.
					   The method of accumulation is total. For possible values, see PROC TIMEDATA documentation.
Short_Reclass		 - Flag to indicate whether the short time span series should be reclassified or not.
					   Possible values are 0 or 1. Default value is 1.
Horizontal_Reclass_Measure	- Measurement for horizontal reclassification.
							  Possible values are Mode, Max_Demand, and None.
							  If None is selected, horizontal reclassification is not initiated. Default value is Mode.
Classify_Deactive	 - Flag to indicate whether the series with Deactive_Flg = 1 should be classified into a separated class type, Deactive.
					   Possible values are 0 or 1. Default value is 0.
Debug 				 - Flag to indicate whether the system should run in debug mode.
					   Possible values are 0 or 1. The default value is 0.

Input Parameters for Analytical Configuration
The following input parameters are supported for analytical configuration:
Setmissing	- The value for the Setmissing argument in the ID statement, when PROC TIMEDATA is called.
			  The default value is 0. For possible values, see PROC TIMEDATA documentation.
Zero_Demand_Flag	- Flag to indicate whether the zero demand method should be applied.
					  Possible values are 0 or 1. Default value is 1.
Zero_Demand_Threshold_Pct	- A user-specified percentage threshold to indicate zero demand.
							  It is used when the Zero_Demand_Flag has a value of 1.
							  Any number less than or equal to this percentage value, is treated as zero demand.
							  No default value is provided. If no value is specified for this parameter,
							  then Zero_Demand_Threshold is used.
Zero_Demand_Threshold	- A user-specified value that is used as a threshold to indicate zero demand.
						  If the Zero_Demand_Flag has a value of 1, and if Zero_Demand_Threshold_Pct is not specified,
						  then any number less than, or equal to this value is treated as zero demand. The default value is 0.
						  Possible values are any number.
Gap_Period_Threshold	- The value for this column is a number, which is a user-specified threshold for
						  indicating that a period is a demand gap period. Possible values are any number equal to or greater than 0.
						  The default value is Ceil (Calendar_Cyc_Period/4).
						  Ceil rounds up a real number to the next larger integral real number.
Short_Series_Period		- Time series with a total number of observations less than or equal to this number
						  are classified as short time series.
						  Possible values are any number greater than or equal to 0.
						  The default value is Ceil (Calendar_Cyc_Period/4). 
Low_Volume_Period_Interval	- Indicates an interval period that is used to classify a series as a Low Volume series.
							  Possible values are any values that indicate a time interval. The default value is Year.
Low_Volume_Period_Max_Tot	- Indicates a maximum period total for low volume test. The default value is 5.
Low_Volume_Period_Max_Occur - The maximum occurrence period for low volume test. Possible values are any number less than or equal to 0.
							  The default value is 0.
LTS_Min_Demand_Cyc_Len	- The minimum length of a demand cycle that is required to be classified as a long time span series.
						  Possible values are any number greater than or equal to 0. The default value is Ceil (3 * Calendar_Cyc_Period/4).
LTS_Seasontest_Siglevel	- The significance level for seasonality test. Possible values are in the range 0–1. Default value is 0.01.
Intermit_Measure	- Measurement for intermittence test. Possible values are Mean and Median. Default value is Median.
Intermit_Threshold	- Threshold value for intermittence test. Possible values are any number greater than or equal to 0.
					  The default value is 2.
Deactive_Threshold	- Threshold for deriving the deactive attribute. That is, a series with trailing zero lengths.
					  Anything beyond this value is treated as deactive.
					  Possible values are any numbers greater than or equal to 0, or not specified.
					  A different method is used if this value is not specified. The default value is 5.
Deactive_Buffer_Period	- A buffer period used for deriving the deactive attribute when the value of Deactive_Threshold is not specified.
						  Possible values are any numbers greater than or equal to 0. The default value is 2.
Calendar_Cyc_Period		- Indicates the number of periods for each calendar cycle.
						  The number of periods is used to establish a deactive status or to perform a seasonality test.
						  Possible values are any number greater than or equal to 0.
						  The default value is equal to the length of the seasonal cycle based on the value of Class Time_Interval.
Lts_Seasontest_Siglevel	- The significance level for seasonality test. Possible values are in the range 0–1. Default value is 0.01.

Input Parameters for Output-Related Configuration
The following input parameters are supported for output-related configuration:
Out_Arrays	- Specifies which demand arrays are requested in the output. Possible values are 0 or 1. Default value is 0.
Out_Class	- Specifies which classification results are requested in the output.
			  Possible values are None, All, and Default (Dc_By only). Default value is Default.
Out_Stats	- Specifies which statistics results are requested in the output.
			  Possible values are None, All, and Default (provides some supported statistics). Default value is None.
Output_Profile	- Flag that indicates that the demand profile is requested for output.
				  Possible values are 0 or 1. Default value is 0.
Profile_Type	- If Output_Profile is 1, then this value indicates the type of demand profiles.
				  Possible values are: Dow, Woy, Moy, or Qoy. Default value is Moy
_Input_Lvl_Result_Table	- Indicates the output table for all selected classification results at the input data level.
						  This value is not included in the output if not specified, or if the value of Out_Class is None.
_Input_Lvl_Stats_Table	- Specifies output table for all selected statistics results specified by Out_Stats and
						  Out_Profile at the input data level. This value is not included in the output if not specified,
						  or if the statistics results are not requested.
_Class_Merge_Result_Table	- Specifies the optional output table for merging the input data with the Dc_By column at Class_Low level.
							  This value is not included in the output if not specified, or if the value of Out_Class is None.
_Class_Low_Result_Table	- Specifies the optional output table for all selected classification results that are specified by Out_Class
						  at Class_Low level. This value is not included in the output if not specified, or if the value of Out_Class is None.
_Class_High_Result_Table - Specifies the optional output table for all selected classification results that are specified by Out_Class
						   at Class_High level. This value is not included in the output if not specified, or if the value of Out_Class is None.
_Class_Low_Stats_Table	- Specifies the optional output table for all selected statistics results that are specified by Out_Stats and Out_Profile at
						  Class_Low level. This value is not included in the output if not specified, or if the statistics results are not requested.
_Class_High_Stats_Table	- Specifies the optional output table for all selected statistics results that are specified by Out_Stats and Out_Profile at
						  Class_High level. This value is not included in the output if not specified, or if the statistics results are not requested.
_Class_Low_Array_Table - Specifies the optional output table for the active demand array results at Class_Low level.
						 This value is not included in the output if not specified, or if the statistics results are not requested.
_Class_High_Array_Table	- Specifies the optional output table for the active demand array results at Class_High level.
						  This value is not included in the output if not specified, or if the statistics results are not requested.
_Class_Low_Calib_Table	- Specifies the optional output table for calibration results at Class_Low level.
						  This value is not included in the output if not specified, or if the statistics results are not requested.
_Class_High_Calib_Table	- Specifies the optional output table for calibration results at Class_High level.
						  This value is not included in the output if not specified, or if the statistics results are not requested.

Input Parameters for Classification Logic-Related Configuration
The following parameter is related to classification logic configuration:
Class_Logic_File	- Specifies the external classification logic file. If this file is specified, the system uses the classification logic that is
					  provided, instead of the system default classification logic to classify the series.
					  For possible values (an existing filename and directory path in a specified format), see “Preliminary Classification” on page 32.
*/

proc means data=data.ready_de;
	var sales_kg;
	class Material;
	output out=test min=MIN max=MAX p1=p1 p5=p5;
run;

proc means data=test;
	var MIN MAX p1 p5;
	output out=test2 median(MIN)=MINMED median(MAX)=MAXMED median(p1)=P1MED median(p5)=P5MED;
run;



%let SYSCC=0;
%dc_class_wrapper(
	indata_table=data.ready_de,
	time_id_var=week,
	demand_var=sales_kg,
/*	input_vars=,
	process_lib=,
	use_package=,
	need_sort=,*/
	hier_by_vars=Subcategory_Code Segment Brand_Segment Sub_Brand Format_Flavor Base_code_Description /*Material_Description*/,
	class_process_by_vars=Subcategory_Code Segment Brand_Segment Sub_Brand Format_Flavor Base_code_Description Material_Description,
	class_low_by_var=Material_Description,
	class_high_by_var=Base_code_Description,
	class_time_interval=week,
	/*short_reclass=,
	horizontal_reclass_measure=, 
	classify_deactive=,
	setmissing=,*/
	zero_demand_flg=0,
	/*zero_demand_threshold=,
	zero_demand_threshold_pct=,
	gap_period_threshold=,
	short_series_period=,*/
	low_volume_period_interval=week,
	low_volume_period_max_tot=5,
	/*low_volume_period_max_occur=,
	lts_min_demand_cyc_len=,
	lts_seasontest_siglevel=,
	intermit_measure=,
	intermit_threshold=,
	deactive_threshold=,
	deactive_buffer_period=,
	calendar_cyc_period=,*/
	out_arrays=1,
	out_class=All,
	out_stats=All,
	out_profile=1,
	profile_type=Moy,
	/*class_logic_file=,*/
	debug=1,
	_input_lvl_result_table=Input_Lvl_Result_Table,
	_input_lvl_stats_table=input_lvl_stats_table,
	_class_merge_result_table=class_merge_result_table,
	_class_low_result_table=class_low_result_table,
	_class_high_result_table=class_high_result_table,
	_class_low_stats_table=class_low_stats_table,
	_class_high_stats_table=class_high_stats_table,
	_class_low_array_table=class_low_array_table,
	_class_high_array_table=class_high_array_table,
	_class_low_calib_table=class_low_calib_table,
	_class_high_calib_table=class_high_calib_table,
	_rc=);

title 'Series Classification Distribution';
proc sgplot data=CLASS_LOW_RESULT_TABLE;
  vbar DC_BY;
run;