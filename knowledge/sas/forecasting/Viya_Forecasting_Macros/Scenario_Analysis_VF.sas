/*
	1.Run the code in Viya - remember to assign sascas1 library.
	2.Results are saved in 'priceoa' output table
	3.Visualisation with 'sgplot' but could take and visualise in VA for a demo
*/
/* Copy the SASHELP.PRICEDATA data set to CAS */
data sascas1.pricedata;
    set sashelp.pricedata;
    where region=1;     /* Forecast sales in Region 1 */
run;

/* Invoke PROC TSMODEL to perform forecast and scoring */
proc tsmodel data=sascas1.pricedata
     outlog=sascas1.pricelog                    /* Output data set for all log output */
     outscalar=sascas1.priceos                  /* Output data set for scalar variables */
     outarray=sascas1.priceoa                   /* Output data set for numeric arrays */
     outobj=(outParamEst=sascas1.outParamEst)   /* Output data set for parameter estimates of chosen model */
     logcontrol=(error=keep warning=keep note=keep none=keep)
     errorstop=yes puttolog=yes lead=12;
id date interval=month;
var sale/accumulate=total;      /* Dependent variable */
var price/accumulate=average;   /* Independent variable */
outscalar modelName $32;
outarray esmExtendedPrice       /* Stochastically extended version of variable "price" */
         entireForecast         /* The ARIMA forecast produced using "esmExtendedPrice" */
         earlyDiscountPrice     /* The perturbed version of "price" used in scoring scenario 1 */
         earlyDiscountForecast  /* The forecast produced for scoring scenario 1 */
         lateDiscountPrice      /* The perturbed version of "price" used in scoring scenario 2 */
         lateDiscountForecast;  /* The forecast produced for scoring scenario 2 */
require atsm;
print outlog;
submit;
    /* Declare arrays used in the scoring process */
    array horizonPrice[1]/nosymbols;        /* Perturbed version of "price" used for scoring */
    array result[1]/nosymbols;              /* Forecast produced by scoring */

    /*
     * Resize the arrays accordingly:
     * Variable _LEAD_: the value of the LEAD= option of the PROC TSMODEL statement.
     */

    call dynamic_array(horizonPrice, _LEAD_);
    call dynamic_array(scoreResult, _LEAD_);

    /* Initialize the data frame used to generate a forecast */
    declare object dataFrame(tsdf);
    rc = dataFrame.Initialize();
    rc = dataFrame.AddY(sale);                  /* Set the dependent series */
    rc = dataFrame.AddX(price,'CONTROL',1);     /* Add "price" as an input variable that can be controlled during scoring */
    rc = dataFrame.SetOption('LEAD', _LEAD_);   /* Specify the forecast lead (needed to retrieve the stochastically extended version of "price") */

    /* Retrive the extended version of "price" (extended using the best exponential smoothing model) */
    rc = dataFrame.GetSeries('price',esmExtendedPrice,'ADJUST','YES');

    /* Diagnose the best ARIMA model for the Y-series */
    declare object diagSpec(diagspec);
    rc = diagSpec.Open();
    rc = diagSpec.SetARIMAX('IDENTIFY', 'BOTH');
    rc = diagSpec.SetARIMAXOutlier();
    rc = diagSpec.Close();

    declare object diag(diagnose);
    rc = diag.Initialize(dataFrame);
    rc = diag.SetSpec(diagSpec);
    rc = diag.Run();

    /* Perform a forecast using the auto-generated ARIMA model */
    declare object forecast(foreng);
    rc = forecast.Initialize(diag);
    rc = forecast.SetOption('CRITERION', 'mape');
    rc = forecast.SetOption('LEAD', _LEAD_);                /* Specify the forecast lead */
    rc = forecast.Run();                                    /* Generate the forecast */
    rc = forecast.GetForecast('PREDICT', entireForecast);   /* Retrieve the complete predicted series */
    modelName = forecast.model();                           /* Retrieve the name of the ARIMA model specification */
    totalPeriods = forecast.nfor();                         /* Retrieve the total length of the predicted series */
    horizonIndex = totalPeriods - _LEAD_;                   /* Compute the length of the historical region */

    /* Store the parameter estimates of the best ARIMA model into a CAS table */
    declare object outParamEst(outest);
    rc = outParamEst.Collect(forecast);

    /* Initialize the scoring object using the ARIMA model forecast */
    declare object scoring(score);
    rc = scoring.Initialize(forecast);

    /*
     * We will investigate two scoring scenarios and evaluate their effect on the forecast:
     * Scenario 1: Lower the product "price" by 1% for the first 3 time periods of the forecast horizon.
     * Scenario 2: Raise the product "price" by 1% for the last 3 time periods of the forecast horizon.
     */

    /* Scenario 1: lower the "price" at the start of the forecast horizon region */
    do i=1 to _LEAD_;
        discountRate = 0.0;
        if i <= 3 then discountRate = 0.01; /* Set a discount rate of 1% for the first 3 time periods */
        horizonPrice[i] = (1.0 - discountRate) * esmExtendedPrice[horizonIndex + i];

        /* Copy the perturbed "price" variable that is used in scoring to an OUTARRAY= data set variable */
        earlyDiscountPrice[horizonIndex + i] = horizonPrice[i];
    end;

    /* Run the scoring process for scenario 1 */
    rc = scoring.SetControl(horizonPrice, 'price');     /* Specify the perturbed "price" variable */
    rc = scoring.Run();                                 /* Perform scoring */
    rc = scoring.GetForecast('PREDICT', scoreResult);   /* Retrieve the predicted series */

    /* Copy the predicted series acquired from scoring to an OUTARRAY= data set variable */
    do i=1 to _LEAD_;
        earlyDiscountForecast[horizonIndex + i] = scoreResult[i];
    end;


    /* Scenario 2: lower the "price" at the end of the forecast horizon region */
    do i=1 to _LEAD_;
        discountRate = 0.0;
        if i >= 10 then discountRate = 0.01;    /* Set a discount rate of 1% for the last 3 time periods */
        horizonPrice[i] = (1.0 - discountRate) * esmExtendedPrice[horizonIndex + i];

        /* Copy the perturbed "price" variable that is used in scoring to an OUTARRAY= data set variable */
        lateDiscountPrice[horizonIndex + i] = horizonPrice[i];
    end;

    /* Run the scoring process for scenario 2 */
    rc = scoring.SetControl(horizonPrice, 'price');     /* Specify the perturbed "price" variable */
    rc = scoring.Run();                                 /* Perform scoring */
    rc = scoring.GetForecast('PREDICT', scoreResult);   /* Retrieve the predicted series */

    /* Copy the predicted series acquired from scoring to an OUTARRAY= data set variable */
    do i=1 to _LEAD_;
        lateDiscountForecast[horizonIndex + i] = scoreResult[i];
    end;
endsubmit;
run;

/* Print the output tables */
proc print data=sascas1.priceos; title 'SCALARS';run;               /* Print scalar variables */
proc print data=sascas1.outParamEst; title 'MODEL PARAMETERS';run;  /* Print the ARIMA model parameters */
proc print data=sascas1.priceoa; title 'SCENARIO ANALYSIS';run;     /* Print the original and scored forecasts */


/*
 * Prepare the original and scored forecasts for plotting.
 */

/* Retrieve the forecast from CAS and sort by the time ID variable */
proc sort data=sascas1.priceoa out=scorePlot;
    by date;
run;

/* Retain the forecast data only over the horizon region */
data scorePlot;
    set scorePlot;
    where missing(sale);

    /* Add labels to each variable (will appear in the plot) */
    label esmExtendedPrice='Original Price'
          entireForecast='Original Forecast'
          earlyDiscountPrice='Early Discount Price (1% for the first 3 months)'
          earlyDiscountForecast='Early Discount Forecast (1% for the first 3 months)'
          lateDiscountPrice='Late Discount Price (1% for the last 3 months)'
          lateDiscountForecast='Late Discount Forecast (1% for the last 3 months)';
run;

/* Plot the original forecast and the scored forecast from scenario 1 */
/* ods graphics on / width=1280px imagename="EarlyDiscount"; */
proc sgplot data=scorePlot;
    title "SASHELP.PRICEDATA: Plot of Total Units Sold vs. Time (Scenario 1).";
    series x=date y=entireForecast / lineattrs=(thickness=8 pattern=solid color=black) name="original";
    series x=date y=earlyDiscountForecast / lineattrs=(thickness=3 pattern=solid color=red) name="earlydiscount";
    yaxis LABEL="Total Units Sold" grid min=1088 max=1253;
    xaxis LABEL="Time" grid;
    keylegend "original" "earlydiscount" / POSITION=Bottom LOCATION=OUTSIDE ACROSS=0 ;
run;

/* Plot the original forecast and the scored forecast from scenario 2 */
/* ods graphics on / width=1280px imagename="LateDiscount"; */
proc sgplot data=scorePlot;
    title "SASHELP.PRICEDATA: Plot of Total Units Sold vs. Time (Scenario 2).";
    series x=date y=entireForecast / lineattrs=(thickness=8 pattern=solid color=black) name="original";
    series x=date y=lateDiscountForecast / lineattrs=(thickness=3 pattern=solid color=green) name="latediscount";
    yaxis LABEL="Total Units Sold" grid min=1088 max=1253;
    xaxis LABEL="Time" grid;
    keylegend "original" "latediscount" / POSITION=Bottom LOCATION=OUTSIDE ACROSS=0 ;
run;

/* Plot the original forecast and the scored forecast from scenario 1 */
/* ods graphics on / width=1280px imagename="EarlyDiscount"; */
proc sgplot data=scorePlot;
    title "SASHELP.PRICEDATA: Plot of Total Units Sold vs. Time (Scenario 1).";
    series x=date y=entireForecast / lineattrs=(thickness=8 pattern=solid color=black) name="original";
    series x=date y=earlyDiscountForecast / lineattrs=(thickness=3 pattern=solid color=red) name="earlydiscount";
    series x=date y=esmExtendedPrice / lineattrs=(thickness=2 pattern=solid color=blue) name="originalprice" Y2Axis;
    series x=date y=earlyDiscountPrice / lineattrs=(thickness=2 pattern=shortdash color=blue) name="earlyprice" Y2Axis;
    yaxis LABEL="Total Units Sold" grid min=1088 max=1253;
    y2axis LABEL="Price Per Unit" min=63 max=67;
    xaxis LABEL="Time" grid;
    keylegend "original" "earlydiscount" "originalprice" "earlyprice" / POSITION=Bottom LOCATION=OUTSIDE ACROSS=0 ;
run;

/* Plot the original forecast and the scored forecast from scenario 2 */
/* ods graphics on / width=1280px imagename="LateDiscount"; */
proc sgplot data=scorePlot;
    title "SASHELP.PRICEDATA: Plot of Total Units Sold vs. Time (Scenario 2).";
    series x=date y=entireForecast / lineattrs=(thickness=8 pattern=solid color=black) name="original";
    series x=date y=lateDiscountForecast / lineattrs=(thickness=3 pattern=solid color=green) name="latediscount";
    series x=date y=esmExtendedPrice / lineattrs=(thickness=2 pattern=solid color=blue) name="originalprice" Y2Axis;
    series x=date y=lateDiscountPrice / lineattrs=(thickness=2 pattern=shortdash color=blue) name="lateprice" Y2Axis;
    yaxis LABEL="Total Units Sold" grid min=1088 max=1253;
    y2axis LABEL="Price Per Unit" min=63 max=67;
    xaxis LABEL="Time" grid;
    keylegend "original" "latediscount" "originalprice" "lateprice" / POSITION=Bottom LOCATION=OUTSIDE ACROSS=0 ;
run;
ods graphics on;

/* Clean up and disconnect from CAS */
%casdsdel(ds=sascas1._all_);
%casclear;
