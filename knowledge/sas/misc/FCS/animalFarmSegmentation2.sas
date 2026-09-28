/**********************************************************************************************
Macro: af_segmentation 

Description: 
Animal Farm Segmentation: This code is to segment the time series into the following 7 segments (animals):
    1. mad bulls: high volume and high volatility 
        (i.e. the time series that are high in value but relatively more difficult to forecast)

    2. horses: high volume and low volatility
        (i.e. the time series that are high in value but relatively easier to forecast automatically)

    3. rabbits: low volume and high volatility
        (i.e. the time series that are low in value but very volatile)

    4. mules: low volume and low volatility
        (i.e. the time series that are low in value and pretty stable)

    5. puppies: new product

    6. kangaroo: intermittent time series

    7. marmots: retired / retiring time series

    8. unsegmented: time series that don't fall in any of the 7 segments

The volume of the time series can be evaluated by MEAN, MAX, MIN or MEDIAN of the series as defined by the user.
By default, this segmentation component will also compare the median of the annual peak with the user-specified
high-volume threshold to capture additional high-volume cases such as the time series only have a few high-volume
spikes driving up the volume. Time series meet the user defined high-volume criteria or the system median annual peak
criteria will be considered as high-volume series.
The volatility of the time series can be evaluated by either the error from the exponential smoothing model (ESM)
or the irregular component from the seasonal decomposition or both.The new product are
evaluated by the length of the time series. The short series will be evaluated by comparing
the length of the series with the user-defined short series threshold.
The intermittent time series are evaluated by the intermittency test (i.e. the median interval of the last 100 observations).
The retired / retiring time series are evaluated by the trailing 'zeros' of the series in which the user
can specify the threshold for the zero. e.g. if the threshold is 1 then any demand that is less
than or equal to 1 will be considered as zero demand.
 
Macro Args:
    - inData: input data set name
    - outData: output data set name
    - time_id: define the time ID variable
    - time_interval: define the time interval (e.g. week)
    - seasonality: define the seasonality of the time series (e.g. 52) 
    - fcst_var: define the forecast variable
    - fcst_var_miss: define how to interpret missing values (e.g. 0)
    - fcst_var_acc: define how to accumulate the time series (e.g. total)
    - by_vars: define the by variables, space delimited.
        if there are more than one by variable (e.g. %str(var1 var2))
    - zero_demand_threshold: A user-specified value that is used as a threshold to indicate zero demand.
        The default value is 0. Possible values are any number. It is used with the zeroDemandThresholdPct,
        the lower value from these two values will be used.
    - zero_demand_threshold_pct: A user-specified percentage threshold to indicate zero demand.
        Any number less than or equal to this percentage value times the maximal value in the demand series,
        is treated as zero demand. It is used with the zeroDemandThreshold, the lower value from
        these two values will be used.
    - short_series_length_threshold: A user-specified threshold for identifying short series.
        If not specified, then the value specified for seasonality is used.
    - inactive_series_length_threshold: A user-specified threshold for identifying retired series.
        If the specified length of time or a longer time having demand lower than the user-specified zero demand,
        it is considered as retire series. If not specified, then the value specified for seasonality is used.
    - intermittency_base: A user-specified threshold for the base of the intermittency test.
        Any value in the series that is lower than this specified base value will be considered as no-demand.
        The default value is 0.
    - intermittency_threshold: A user-specified threshold to compare with the median of the demand interval.
        If the median of the demand interval is greater than this threshold,
        then the series is considered as intermittent series. The default value is 2.
    - volume_measure: A user-specified measurement for measuring volume. Possible value can be MEAN, MEDIAN, MIN, MAX.
    - volume_threshold: A user-specified threshold for identifying high / low volume series.
    - volume_threshold_pct:	If the volume threshold is not specified, then this user-specified number will be used to
        take the top percentage of the total number of series ranked by the volume measure from highest to
        lowest as high-volume series. If this percentage is not specified, then the top 10% of total number
        of series ranked by volume measure will be considered as high-volume series.
        Possible value is any number between 0 and 1.
    - transform: A user-specified forecast variable transformation function
    - transform_fcst: A user-specified value to set the mean or median forecast values to be estimated.
        If no transformation is applied to the actual series with the transform option,
        the mean and the median time series forecast values are identical.
        Possible value can be MEAN or MEDIAN.
    - fit_criterion: A user-specified model selection criterion (statistic of fit) for the Exponential Smoothing models
    - volatility_measure: A user-specified measurement for measuring volume.
        Possible value can be MinAE, MedAE, MAE, MaxAE, MinAPE, MedAPE, MAPE, MaxAPE.
    - volatility_threshold: A user-specified threshold for identifying high / low volatility series.
    - volatility_threshold_pct: If the volatility threshold is not specified, then this user-specified number will
        be used to take the top percentage of the total number of series ranked by the volatility measure from
        highest to lowest as the highly volatile series. If this percentage is not specified,
        then the top 10% of total number of series ranked by volatility measure will be considered as
        high-volatility series. Possible value is any number between 0 and 1.
    - strategy: Selecting from one of the two implemented strategies in calculating volatility: the first strategy is
        fitting the series with a simple time series model and the second strategy is conducting seasonal
        decomposition on the series. Value 1 indicates using the first strategy,
        value 2 indicates using the second strategy and any other value indicates using both of these two strategies.
    - cmp_lib: define the library of the demand classification fcmp function. Default is work.timefnc

************************************************************************************************/
%macro af_segmentation(
    inData = ,
    outData = ,
    time_id = ,
    time_interval = ,
    seasonality = ,
    fcst_var = ,
    fcst_var_miss = ,
    fcst_var_acc = ,
    by_vars = ,
    zero_demand_threshold = ,
    zero_demand_threshold_pct = ,
    short_series_length_threshold = ,
    inactive_series_length_threshold =,
    intermittency_base = 0,
    intermittency_threshold = 2,
    volume_measure = MEAN,
    volume_threshold =,
    volume_threshold_pct = 0.1,
    transform = NONE,
    transform_fcst = MEDIAN,
    fit_criterion = MAE,
    volatility_measure =MAPE,
    volatility_threshold =,
    volatility_threshold_pct = 0.1,
    strategy =,
    cmp_lib = work.timefnc
    );

*------define FCMP functions------*;
/****************************************************************************************

NAME:           fcmpFunctions

DESCRIPTION:    fcmp functions/subroutines for computing statistics about each time series

FUNCTION LIST: 
                function dc_lead_zero_length(timedata[*], zero_demand_threshold); 
                function dc_trail_zero_length(timedata[*], zero_demand_threshold);
                subroutine dc_compute_sum(timedata[*], sum, count);
                function dc_compute_stdev(timedata[*], mean, count);
                subroutine dc_compute_mean(timedata[*], mean, count); 
                subroutine dc_compute_order_stats(timedata[*], min, median, max);
                subroutine dc_compute_basic_stats(timedata[*], count, mean, stdev, min, median, max);
                function dc_average_demand_interval(actual[*]);

****************************************************************************************/
%if %sysfunc(exist(&cmp_lib)) %then %do;
    proc sql noprint;
        drop table &cmp_lib;
    quit;
%end;
proc fcmp outlib=&cmp_lib..funcs; 

    /***********************************************************************************************************
        API:
                    dc_lead_zero_length(timedata[*], zero_demand_threshold);
        Type:
                    Function
        Purpose: 
                    compute the length of the leading zero part of the time series
        Input:   
                    timedata[*]           : time series array 
                    zero_demand_threshold : any number <= zero_demand_threshold will be treated as zero demand
        Output: 
                    return an integer number indicating the length of the leading zero part of the time series 
    ***********************************************************************************************************/
    function dc_lead_zero_length(timedata[*], zero_demand_threshold);
        size = dim(timedata);
        lead =0;
        if size>0 then do;
            if zero_demand_threshold ne . then do;
                do i=1 to size;
                    if timedata[i] ne . and (timedata[i]>zero_demand_threshold or (zero_demand_threshold>=0 and timedata[i]<-zero_demand_threshold)) then do;
                        lead = i-1;
                        return (lead);
                    end;
                end;
            end;
            else do;
                do i=1 to size;
                    if timedata[i] ne . then do;
                        lead = i-1;
                        return (lead);
                    end;
                end;
            end;
            lead=size;
        end;
        return (lead);
    endsub;

    /***********************************************************************************************************
        API:
                    dc_trail_zero_length(timedata[*], zero_demand_threshold);
        Type:
                    Function
        Purpose: 
                    compute the length of the traiing zero part of the time series
        Input:   
                    timedata[*]            : time series array 
                    zero_demand_threshold  : any number <= zero_demand_threshold will be treated as zero demand
        Output: 
                    return an integer number indicating the length of the trailing zero part of the time series 
    ***********************************************************************************************************/
    function dc_trail_zero_length(timedata[*], zero_demand_threshold);
        size = dim(timedata);
        trail =0;
        if size>0 then do;
            if zero_demand_threshold ne . then do;
                do i=1 to size;
                    j=size-i+1;
                    if timedata[j] ne . and (timedata[j]>zero_demand_threshold or (zero_demand_threshold>=0 and timedata[j]<-zero_demand_threshold)) then do;
                        trail = i-1;
                        return (trail);
                    end;
                end;
            end;
            else do;
                do i=1 to size;
                    j=size-i+1;
                    if timedata[j] ne . then do;
                        trail = i-1;
                        return (trail);
                    end;
                end;            
            end;
            trail=size;
        end;
        return (trail);
    endsub;
        

    /***********************************************************************************************************
        API:
                    dc_compute_sum(timedata[*], sum, count);
        Type:
                    Subroutine
        Purpose: 
                    compute the summation of the elements of the time series array and count the total number of non-missing elements
        Input:   
                    timedata[*] : time series array 
                    
        Output: 
                    sum         : the summation of the non-missing elements
                    count       : count of the total number of non-missing elements
    ***********************************************************************************************************/
    subroutine dc_compute_sum(timedata[*], sum, count);
        outargs sum, count;
        sum = .;
        count=0;
        length=dim(timedata);
        if length>0 then do;
            sum=0;
            do i=1 to length;
                if timedata[i] ne . then do;
                    sum = sum + timedata[i];
                    count = count+1;
                end;
            end;
            if count=0 then sum=.;
        end;
    endsub;

    /***********************************************************************************************************
        API:
                    dc_compute_mean(timedata[*], mean, count);
        Type:
                    Subroutine
        Purpose: 
                    compute the mean of the time series array
        Input:   
                    timedata[*] : time series array 
        Output: 
                    sum            : the mean of the non-missing elements
                    count          : count of the total number of non-missing elements
    ***********************************************************************************************************/
    subroutine dc_compute_mean(timedata[*], mean, count);
        outargs mean, count;
        mean = .;
        count=0;
        length=dim(timedata);
        if length>0 then do;
            call dc_compute_sum(timedata, sum, count);
            if count>0 and sum ne . then mean = sum / count;
        end;
    endsub;
        
     /***********************************************************************************************************
         API:
                     dc_compute_stdev(timedata[*], mean, count);
         Type:
                     Function
         Purpose: 
                     compute the standard deviation of the non-missing elements of the time series array with given mean
         Input:   
                     timedata[*] : time series array 
                     count       : the total number of non-missing obervations
                     mean        : mean of the observations
         Output: 
                     return a float value as the stdev or . if count<=1
     ***********************************************************************************************************/
     function dc_compute_stdev(timedata[*], mean, count);
         stdev = .;
         length=dim(timedata);
         if length>0 and count>1 and mean^=. then do;
              temp = 0;
             do i=1 to length;
                 if timedata[i] ^= . then temp = temp + (timedata[i]-mean)**2;
             end;
             stdev = sqrt (temp / (count-1));
         end;
         return (stdev);
     endsub;


    /***********************************************************************************************************
        API:
                    dc_compute_order_stats(timedata[*], min, median, max);
        Type:
                    Subroutine
        Purpose: 
                    compute the min, median and max of the non-missing elements of the time series array 
        Input:   
                    timedata[*] : time series array 
        Output: 
                    min         : float value as the mininum of the obervations
                    median      : float value as the median of the obervations
                    max         : float value as the maxinum of the obervations

    ***********************************************************************************************************/
    subroutine dc_compute_order_stats(timedata[*], min, median, max);
        outargs min, median, max;
        array order[1]/NOSYMBOLS;
        min = .;
        median = .;
        max = .;
        length=dim(timedata);
        if length>0 then do;
            /*sort the array by ascending order*/
            call dynamic_array(order, length);
            count=0;
            do i=1 to length;
                if timedata[i] ne . then do;
                    count = count+1;
                    order[count]=timedata[i];
                end;
            end;
            if count>0 then do;
                if count=1 then do;
                    min = order[1];
                    median = order[1];
                    max = order[1];
                end;
                else do;  /*case count > 1*/
                    do i=1 to count-1;
                        do j=1 to count-1;
                            if order[j]>order[j+1] then do;
                                temp = order[j];
                                order[j]=order[j+1];
                                order[j+1]=temp;
                            end;
                        end;
                    end;
                    min=order[1];
                    max=order[count];
                    index=floor(count/2);
                    if index*2<count then median = order[index+1];
                    else median = (order[index]+order[index+1])/2;
                end;
            end;
        end;
    endsub;

    /***********************************************************************************************************
        API:
                    dc_compute_basic_stats(timedata[*], count, mean, stdev, min, median, max);
        Type:
                    Subroutine
        Purpose: 
                    compute the count, mean, stdev, min, median and max of the non-missing elements of the time series array 
        Input:   
                    timedata[*] : time series array 
        Output: 
                    count       : integer as the total number of non-missing elements of the time series array
                    mean        : float value as the mean of the non-missing elements of the time series array
                    stdev       : float value as the standard deviation of the non-missing elements of the time series array
                    max         : float value as the maxinum of the non-missing elements of the time series array
                    min         : float value as the mininum of the non-missing elements of the time series array
                    median      : float value as the median of the non-missing elements of the time series array
                    max         : float value as the maxinum of the non-missing elements of the time series array

    ***********************************************************************************************************/
    subroutine dc_compute_basic_stats(timedata[*], count, mean, stdev, min, median, max);
        outargs count, mean, stdev, min, median, max;
        count=0;
        mean=.;
        stdev=.;
        min=.;
        median=.;
        max=.;
        call dc_compute_mean(timedata, mean, count);
        stdev = dc_compute_stdev(timedata, mean, count);
        call dc_compute_order_stats(timedata, min, median, max);
    endsub;

    /***********************************************************************************************************
    API:
                dc_average_demand_interval(actual[*]);
    Type:
                Function
    Purpose: 
                Compute average demand interval
    Input:   
                actual[*] : demand array
    Return: 
                Average Demand Interval
                
    ***********************************************************************************************************/
    function dc_average_demand_interval(actual[*]);
        actlen  = dim(actual);
        sum = 0;
        interval = 1;
        nintervals = 0;
        do t = 1 to actlen;
            value = actual[t];
            if nmiss(value) | value = 0 then do;
                interval = interval + 1;
            end;
            else do;
                sum = sum + interval;
                interval = 1;
                nintervals = nintervals + 1;
            end;
        end;
        return( sum / nintervals );
    endsub;
run; 
quit; 
*end of PROC FCMP;

*define the cmplib system option;
options cmplib = &cmp_lib;

*sort input data with the provided by_vars;
proc sort data = &inData out = _inData;
   by &by_vars &time_id;
run;

*------validate input arg values------*;
%if "&short_series_length_threshold" = "" %then %do;
    %let short_series_length_threshold = &seasonality;
%end;
%if "&inactive_series_length_threshold" = "" %then %do;
    %let inactive_series_length_threshold = &seasonality;
%end;
%if "&intermittency_threshold" = "" %then %do;
    %let intermittency_threshold = 2;
%end;
%if "%upcase(&transform_fcst)" ne "MEDIAN" %then %do;
    %let transform_fcst =;
%end;

*replace blanks with commas;
%let byVarsComma = %sysfunc(tranwrd(%cmpres(&by_vars), %str( ), %str(,)));

*seasonal decomposition;
proc timeseries data = _inData outdecomp = _outdecomp(keep = &by_vars &time_id ic);
    by &by_vars;
    id &time_id interval = &time_interval;
    var &fcst_var / setmissing = &fcst_var_miss acc = &fcst_var_acc;
    decomp ic/mode = add;
run;

*esm models;
proc hpf data = _inData out = null outfor = _outfor(keep = &by_vars &time_id predict) lead = 0;
    by &by_vars;
    id &time_id interval = &time_interval;
    forecast &fcst_var/criterion = &fit_criterion model = best transform = &transform &transform_fcst 
             setmissing = &fcst_var_miss acc = &fcst_var_acc;
run;

data _inData;
    merge _indata _outdecomp _outfor;
    by &by_vars &time_id;
run;

*------generate necessary scalars for number of nonmissing obs, intermittency test, trailing zeros------*;
proc timedata data = _inData outscalars = outscalars outarray = outarray out = out_ts;
    by &by_vars;
    id &time_id interval = &time_interval;
    var &fcst_var ic predict/ setmissing = &fcst_var_miss acc = &fcst_var_acc;

    *define output scalars;
    outscalars 
        local_zero_demand_threshold trailing_zero_len leading_zero_len series_len
        intermittent_flag med short_series_flag retire_flag average_demand_interval
        min median mean max
        countae_s1 mae_s1 stdevae_s1 minae_s1 medae_s1 maxae_s1
        countape_s1 mape_s1 stdevape_s1 minape_s1 medape_s1 maxape_s1
        countae_s2 mae_s2 stdevae_s2 minae_s2 medae_s2 maxae_s2
        countape_s2 mape_s2 stdevape_s2 minape_s2 medape_s2 maxape_s2;

    *define output arrays;
    outarray esm_ae esm_ape decomp_ae decomp_ape adjust;

    *adjust zero_demand_threshold and get trailing zeros;
    call dc_compute_basic_stats(&fcst_var, series_len , mean, stdev, min, median, max);
    local_zero_demand_threshold = min(%eval(&zero_demand_threshold),%sysevalf(&zero_demand_threshold_pct)*max);

    trailing_zero_len = dc_trail_zero_length(&fcst_var, local_zero_demand_threshold);
    leading_zero_len = dc_lead_zero_length(&fcst_var, local_zero_demand_threshold);

    if series_len lt %eval(&short_series_length_threshold) then short_series_flag = 1;
    else short_series_flag = 0;

    if trailing_zero_len ge %eval(&inactive_series_length_threshold) then retire_flag = 1;
    else retire_flag = 0;

    *intermittency data adjustment;
    do j = 1 to dim(&fcst_var);
       adjust[j] = &fcst_var[j];
       if &fcst_var[j] le %eval(&intermittency_base) then adjust[j] = 0;
    end;

    *intermittency test;
    intermittent_flag = 0;
    average_demand_interval = dc_average_demand_interval(adjust);
    if average_demand_interval > &intermittency_threshold then intermittent_flag = 1;

    do i = 1 to dim(&fcst_var);
        esm_ae[i] = abs(sum(&fcst_var[i], -predict[i]));
        esm_ape[i] = divide(abs(sum(&fcst_var[i], -predict[i])), abs(&fcst_var[i]));
        decomp_ae[i] = abs(ic[i]);
        decomp_ape[i] = divide(abs(ic[i]), abs(&fcst_var[i]));

        *exclude infinite values;
		if esm_ape[i] = .i then esm_ape[i] = .;
		if decomp_ape[i] = .i then decomp_ape[i] = .;
	end;

    call dc_compute_basic_stats(esm_ae, countae_s1, mae_s1, stdevae_s1, minae_s1, medae_s1, maxae_s1);
    call dc_compute_basic_stats(esm_ape, countape_s1, mape_s1, stdevape_s1, minape_s1, medape_s1, maxape_s1);
    call dc_compute_basic_stats(decomp_ae, countae_s2, mae_s2, stdevae_s2, minae_s2, medae_s2, maxae_s2);
    call dc_compute_basic_stats(decomp_ape, countape_s2, mape_s2, stdevape_s2, minape_s2, medape_s2, maxape_s2);

    *re-classify slow series;
    if sum(series_len, -trailing_zero_len, -leading_zero_len) le 1 then do;
       intermittency_flag = 0;
       short_series_flag = 0;
       retire_flag = 0;
    end;
run; 

*double check median of yearly peak;
proc sql;
    create table out_ts_year as
    select unique &byVarsComma, mdy(1,1,year(&time_id)) as year, max(&fcst_var) as peak
    from out_ts
    group by &byVarsComma, year;
quit;

proc timedata data = out_ts_year outscalars = outscalars2;
    by &by_vars;
    id year interval = year;
    var peak / setmissing = &fcst_var_miss acc = &fcst_var_acc;

    outscalars  min median mean max;
    call dc_compute_basic_stats(peak, count , mean, stdev, min, median, max);
run;

*compute volume_peak;
%if "&volume_threshold" ne "" %then %do;
    data temp_vol;
        set outscalars;
        if &volume_measure ge %sysevalf(&volume_threshold) then volume_user_defined = "H";
        else volume_user_defined = "L";
        volume_measure_user_defined = &volume_measure;
    run;

    data outscalars2;
        set outscalars2;
        if median ge %sysevalf(&volume_threshold) then volume_peak = "H";
        else volume_peak = "L";
        volume_measure_peak = median;
    run;
%end;
%else %do;
    *derive volume_threshold if not specified;
    data _null_;
        set outscalars;
        local_volume_threshold = ceil(_n_* &volume_threshold_pct);
        call symputx('local_volume_threshold', local_volume_threshold, 'l');
    run;

    proc sort data = outscalars out = temp_vol;
        by descending &volume_measure;
    run;

    data temp_vol;
        set temp_vol;
        if _n_ le %eval(&local_volume_threshold) then volume_user_defined = "H";
        else volume_user_defined = "L";
        volume_measure_user_defined = &volume_measure;
    run;

    proc sort data = outscalars2;
        by descending median;
    run;

    data outscalars2;
        set outscalars2;
        if _n_ le %eval(&local_volume_threshold) then volume_peak = "H";
        else volume_peak = "L";
        volume_measure_peak = median;
    run;
%end;

proc sort data = temp_vol;
    by &by_vars;
run;

proc sort data = outscalars2;
    by &by_vars;
run;

data outscalars;
    merge temp_vol outscalars2(keep = &by_vars VOLUME_PEAK VOLUME_MEASURE_PEAK);
    by &by_vars;
    if volume_user_defined = "H" or volume_peak = "H" then volume = "H";
    else volume = "L";
run; 


*compute volatility_1 and volatility_2;
%if "&volatility_threshold" ne "" %then %do;
    data outscalars;
        set outscalars;
        if &volatility_measure._s1 ge %sysevalf(&volatility_threshold) then volatility_1 = "H";
        else volatility_1 = "L";

        if &volatility_measure._s2 ge %sysevalf(&volatility_threshold) then volatility_2 = "H";
        else volatility_2 = "L";
  run;
%end;
%else %do;
    *derive volatility_threshold based on volatility_threshold_pct;
    data _null_;
        set outscalars;
        local_volatility_threshold = ceil(_n_* &volatility_threshold_pct);
        call symputx('local_volatility_threshold', local_volatility_threshold, 'l');
    run;
    proc sort data = outscalars;
        by descending &volatility_measure._s1;
    run;

    data outscalars;
        set outscalars;
        if _n_ le %eval(&local_volatility_threshold) then volatility_1 = "H";
        else volatility_1 = "L";
    run;

    proc sort data = outscalars;
        by descending &volatility_measure._s2;
    run;

    data outscalars;
        set outscalars;
        if _n_ le %eval(&local_volatility_threshold) then volatility_2 = "H";
        else volatility_2 = "L";
    run;
%end;


*define the if statement used in the output table data step;
%local if_statement;
%if "&strategy" = "1" %then %let if_statement = %str(volatility_1 = "H");
%else %if "&strategy" = "2" %then %let if_statement = %str(volatility_2 = "H");
%else %let if_statement = %str(volatility_1 = "H" or volatility_2 = "H");

*segment series based on the stats derived from the processes above;
data &outData;
    length seg_group $10;
    set outscalars (rename=(&volatility_measure._s1 = volatility_measure_1 &volatility_measure._s2 = volatility_measure_2)
                    keep = &by_vars short_series_flag intermittent_flag retire_flag
                           volume volume_user_defined volume_peak volume_measure_user_defined
                           volume_measure_peak volatility_1 volatility_2 
                           &volatility_measure._s1 &volatility_measure._s2);

    if &if_statement then volatility = "H";
    else volatility = "L";

    if sum(short_series_flag, intermittent_flag, retire_flag) ge 1 then do;
         volume = " ";
         volatility = " ";
         volatility_1 = " ";
         volatility_2 = " ";
         volatility_measure_1 = .;
         volatility_measure_2 = .;
    end;

    if volatility = "H" and volume = "H" then do;
        seg_group = "MAD_BULLS";
    end;
    else if volatility = "L" and volume = "H" then do;
        seg_group = "HORSES";
    end;
    else if volatility = "H" and volume = "L" then do;
        seg_group = "RABBITS";
    end;
    else if volatility = "L" and volume = "L" then do;
        seg_group = "MULES";
    end;
    else do;
        if short_series_flag then do; 
            seg_group = "PUPPIES";
        end;
        else do;
            if intermittent_flag then do;
                seg_group = "KANGAROOS";
            end;
            else do;
                if retire_flag then do;
                    seg_group = "MARMOTS";
                end;
                else do;
                    seg_group = "UNSEGMENTED";
                end;
            end;
        end;
    end;
run;
%mend af_segmentation;
