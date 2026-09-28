%include "D:\Codes\Forecasting\FCS\animalFarmSegmentation2.sas";

data pricedata;
	set sashelp.pricedata;

	if productName = "Product1" and month(date) ne 1 then
		sale = .;

	if productName = "Product2" and date ge "01mar1998"d then
		sale = .;
run;

%af_segmentation(
	inData = pricedata,
	outData = segmentation_result,
	time_id = date,
	time_interval = month,
	seasonality = 12,
	fcst_var = sale,
	fcst_var_miss = 0,
	fcst_var_acc = total,
	by_vars = %str(region productLine productName),
	zero_demand_threshold = 1,
	zero_demand_threshold_pct = 0.1,
	short_series_length_threshold = ,
	inactive_series_length_threshold = 12,
	intermittency_base = 0,
	intermittency_threshold = 2,
	volume_measure = mean,
	volume_threshold = 500,
	volume_threshold_pct = 0.1,
	transform = none,
	transform_fcst = mean,
	fit_criterion = mae,
	volatility_measure = mape,
	volatility_threshold = 0.5,
	volatility_threshold_pct = 0.1,
	strategy =,
	cmp_lib = work.timefnc 
	);