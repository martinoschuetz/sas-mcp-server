/* Open Source with Auto-Forecasting Node
	Paper: https://www.sas.com/content/dam/SAS/support/en/sas-global-forum-proceedings/2018/2027-2018.pdf
*/

/*-------------------------------------------------------------------
 * copyright (c) 2018 by SAS Institute Inc., Cary NC
 * name    : vf_auto_forecast.sas
 * purpose : Example of using Proc TSMODEL to forecast.  
 *           Generate forecast using  auto-forecasting model to include
                more model families: with ESM, IDM, UCM or ARIMAX model
 *------------------------------------------------------------------- 
 *  List of strategy specific properties for this Sample
 *  (available as sas MACRO variable to be used in code):
 *     _arimaxInclude            - Specify whether to include ARIMAX model
 *                                 for diagnosis
 *     _esmInclude               - Specify whether to include ESM model
 *                                 for diagnosis
 *     _idmInclude               - Specify whether to include IDM model
 *                                 for diagnosis
 *     _intermittencySensitivity - Sensitivity for intermittency test
 *     _idmMethod                - IDM method 
 *     _ucmInclude               - Specify whether to include UCM model
 *                                 for diagnosis
 *     _combInclude              - Specify whether to combine the models
 *                                 other than the external ones for 
 *                                 diagnosis
 *     _minobs                   - Minimum number of observations for a 
 *                                 non-mean model
 *     _minobsTrend              - Minimum number of observations for a
 *                                 trend model
 *     _minobsSeason             - Minimum number of seasonal cycles for
 *                                 a seasonal model
 *     _holdoutSampleSize        - Size of data to be used for holdout
 *     _holdoutSamplePercent     - Percentage of data to be used for 
 *                                 holdout
 *     _modelSelection_criteria  - Model selection criteria
 *     _forecastBack             - Calculate statistics of fit over 
 *                                 an out of sample range
 *     _leadExtend               - Specify whether to extend the lead
 *                                 to count for the value specified 
 *                                 for both of lead and back
 *------------------------------------------------------------------- 
 * Component needs to produce output datasets and promote to &vf_caslibOut as necessary.
 * Output dataset names:
 *     &vf_outFor   - Required table containing forecast results. It
 *                    contains BY variables, TimeID, ACTUAL, PREDICT,
 *                    STD(OPTIONAL), LOWER(OPTIONAL), UPPER(OPTIONAL), 
 *                    ERROR(OPTIONAL)
 *     &vf_outStat  - Optional table. The model summary statistics table. Table contains
 *                    BY variables, statistics for the model and the
 *                    following variables:
 *                    _NAME_      variable name of dependent variable
 *                    _REGION_    the region statistics are calculated
 *                    _SELECT_    selection list
 *                    _MODEL_     model
 *     &vf_outInformation - Optional table containing execution summary
 *                          information (the processing information of TSMODEL) such as
 *                          Number of groups processed by submitted code,  Number of groups failing, and etc.  
 *     &vf_outModelInfo   - Optinal table containing model information
 *-------------------------------------------------------------------
 * MACROS IN THE EXAMPLE:
 *-------------------------------------------------------------------
 * Component needs to produce output datasets and promote to &vf_caslibOut as necessary.
 *  Output dataset names:
 *  OUTFOR:      Required Table contains BY variables, TimeID, ACTUAL, PREDICT, STD(OPTIONAL), LOWER(OPTIONAL), 
 *  UPPER(OPTIONAL), ERROR(OPTIONAL)
 *  OUTSTAT:     Optional Table contains BY variables, statistics for the model and following variables:
 *               _NAME_      variable name of dependent variable
 *               _REGION_    the region statistics are calculated
 *               _SELECT_    selection list
 *               _MODEL_     model
 *               
 * OUTINFORMATION: Optional Table contains the processing information of TSMODEL such as                   
 *                  Number of groups processed by submitted code,  Number of groups failing, and etc.  
 *
 * In this example only OUTFOR, OUTSTAT, and OUTINFORMATION are generated.
*-------------------------------------------------------------------

/*-------------------------------------------------------------------
 * Forecast at a particular level
 *-----------------------------------------------------------------*/

*request ODS output outInfo and name it as sforecast_outInformation;
ods output OutInfo = sforecast_outInformation;

*run TSMODEL to generate forecasts;
%if %eval(%symexist(_holdoutSamplePercent) eq 0) %then %do; 
    %let _holdoutSamplePercent = .;
%end;

proc tsmodel data = &vf_libIn.."&vf_inData"n
          logcontrol = (error = keep warning = keep)
          /*outSum = &outsum
          outlog = &outlog*/
          %if "&vf_inEventObj" ne "" %then %do;
             inobj = (&vf_inEventObj)
          %end;
          outobj = (
                       outfor  = &vf_libOut.."&vf_outFor"n
                       outstat = &vf_libOut.."&vf_outStat"n
                       outSelect = &vf_libOut.."&vf_outSelect"n
                       outmodelinfo = &vf_libOut.."&vf_outModelInfo"n
					   rvars = &vf_libOut..rvars
					   rlog = &vf_libOut..rlog
                       )
          outlog  = &vf_libOut.."&vf_outLog"n          
		  outarray = &vf_libOut..outarray 
          errorstop = YES
		  lead = &vf_lead
          ;
          
    *define time series ID variable and the time interval;
    id &vf_timeID interval = &vf_timeIDInterval
                  setmissing = &vf_setMissing trimid = LEFT;

    *define time series and the corresponding accumulation methods;
    %vf_varsTSMODEL;
outarray rPred;
    *define the by variables if exist;
    %if "&vf_byVars" ne "" %then %do;
       by &vf_byVars;
    %end;

    *using the ATSM (Automatic Time Series Model) package;
    require atsm tsm extlang;

    *starting user script;
    submit;
    
        /*declare ATSM objects;*/
        /*
        TSDF:     Time series data frame used to group series variables for DIAGNOSE and FORENG objects
        DIAGNOSE: Automatic time series model generation
        FORENG:   Automatic time series model selection and forecasting
        DIAGSPEC: Diagnostic control options for DIAGNOSE object
        OUTFOR:   Collector for FORENG forecasts
        OUTSTAT:  Collector for FORENG forecast performance statistics
        */
        /* Create R model */
		declare object robj(R) ;
		rc = robj.Initialize() ;
		*rc10 = robj.PushCodeFile('/opt/sasinside/DemoData/R/r_arima_code.r') ;
		rc = robj.PushCodeLine('library(forecast)') ;
		rc = robj.PushCodeLine('') ;
		rc = robj.PushCodeLine('PREDICT <- seq(1.1, 156.1, by=1.0)') ;
		** The Y passed in from SAS will contain the trailing missing values for the horizon,
		** which the R functions we use do not want there ;
		rc = robj.PushCodeLine('Y <- Y[1:(NFOR - HORIZON)]') ;
		rc = robj.PushCodeLine('Y_ts <- ts(Y, frequency=12)') ;
		**rc = robj.PushCodeLine('Y_ts <- window(Y_ts, 1, c(length(Y_ts), 12) )') ;
		rc = robj.PushCodeLine('log_Y_ts <- log(Y_ts)') ;
		rc = robj.PushCodeLine('') ;
		rc = robj.PushCodeLine('model <- stats::arima(log_Y_ts, order=c(p=0, d=1, q=1), seasonal=list(order=c(0,1,1), frequency=12))');
		**rc = robj.PushCodeLine('summary(model)') ;

		rc = robj.PushCodeLine('a <- stats::predict(model, n.ahead=HORIZON)') ;
		rc = robj.PushCodeLine('PREDICT <- c( exp(fitted.values(model)), exp(a$pred) )') ;

		/* Specify shared variables for R */
		rc = robj.addVariable(&vf_depVar, 'ALIAS', 'Y') ;
		rc = robj.addVariable(rPred, 'ALIAS', 'PREDICT', 'READONLY', 'FALSE') ;
		rc = robj.addVariable(_LENGTH_, 'ALIAS', 'NFOR') ;
		rc = robj.AddVariable(_LEAD_,'ALIAS','HORIZON') ;

		/* Run the model and get the exit code and run time */
		rc = robj.Run();
		rExitCode = robj.GetExitCode() ;
		rRuntime = robj.GetRunTime() ;

		declare object rlog(OUTEXTLOG) ; 
		rc = rlog.Collect(robj, 'EXECUTION');
		
		declare object rvars(OUTEXTVARSTATUS);
		rc = rvars.collect(robj);
		
		/* Create external model specification for the R model */ 
		declare object rExmSpec(EXMSPEC); 
		rc = rExmSpec.open(); 
		rc = rExmSpec.setOption('METHOD','PERFECT'); 
		rc = rExmSpec.setOption('NLAGPCT',0); 
		rc = rExmSpec.setOption('NPARMS',2); 
		rc = rExmSpec.setOption('PREDICT','rPred'); 
		rc = rExmSpec.close();
		
		
		
	declare object dataFrame(tsdf);
        declare object diagnose(diagnose);
        declare object diagSpec(diagspec);
        declare object inselect(selspec); 
        declare object forecast(foreng);
        
        /*initialize the tsdf object and assign the time series roles: setup dependent and independent variables*/
        rc = dataFrame.initialize();
        rc = dataFrame.AddSeries(rPred);
        rc = dataFrame.addY(&vf_depVar);
        *add independent variables to the tsdf object if there is any;
        %if "&vf_indepVars" ne "" %then %do;
            %vf_addXTSMODEL(dataFrame);
        %end;
    
        /*setup up event information*/
        %if "&vf_inEventObj" ne "" or "&vf_events" ne "" %then %do;
            declare object ev1(event);
            rc = ev1.Initialize();
            %vf_addEvents(dataFrame, ev1);
        %end;
       
        /*open and setup the diagspec object and enable ESM, IDM, UCM and ARIMAX model class for diagnose;*/
        /*setup time series diagnose specifications*/
        /*open the diagspec object and enable ESM, IDM, UCM, ARIMAX model class for diagnose; */
        rc = diagSpec.open();
        %if %UPCASE("&_esmInclude") eq "TRUE"  %then %do;
            rc = diagSpec.setESM('method', 'BEST');
        %end;
        %if %UPCASE("&_arimaxInclude") eq "TRUE"  %then %do;
            rc = diagSpec.setARIMAX('identify', 'BOTH');
        %end;
        %if %UPCASE("&_idmInclude") eq "TRUE" %then %do;
            rc = diagSpec.setIDM('intermittent', 
                                 &_intermittencySensitivity);   
            rc = diagSpec.setIDM('METHOD', "&_idmMethod");
        %end;
        %else %do;
            rc = diagSpec.setIDM('intermittent', 10000);
        %end;
        %if %UPCASE("&_ucmInclude") eq "TRUE" %then %do;
            rc = diagSpec.setUCM();
        %end;

        rc = diagSpec.close();
    
        /*diagnose time series to generate candidate model list*/
        /*set the diagnose object using the diagspec object and run the diagnose process; */
        rc = diagnose.initialize(dataFrame);
        rc = diagnose.setSpec(diagSpec);
		%vf_setObjectOptions(instance=diagnose, object=diagnose)   

/*		Comment out the following two lines to run RNN model only*/
        rc = diagnose.Run();
        ndiag = diagnose.nmodels();                                 
            
        /*Run model selection and forecast*/                     
        rc = inselect.Open(1); 
        rc = inselect.AddFrom(rExmSpec);
        rc = inselect.close(); 
        
        /*initialize the foreng object with the dataframe result and run model selecting and generate forecasts;*/         
        rc = forecast.initialize(dataFrame);

/*		Run the following line of code to diagnose SAS models along with R models*/
		rc = forecast.initialize(diagnose);

		rc = forecast.AddFrom(inselect);
   		%vf_setObjectOptions(instance=forecast, object=foreng)
        rc = forecast.Run();
    
        /*collect forecast results*/
        declare object outFor(outFor);
        declare object outStat(outStat);
        declare object outSelect(outSelect);
        declare object outModelInfo(outModelInfo);
    
        /*collect the forecast and statistic-of-fit from the forgen object run results; */
        rc = outFor.collect(forecast);
        rc = outStat.collect(forecast);
        rc = outSelect.collect(forecast);  
        rc = outModelInfo.collect(forecast);
    endsubmit;
quit;


*generate outinformation CAS table;
data &vf_libOut.."&vf_outInformation"n;
    set work.sforecast_outInformation;
run;



/*******************************************************************************************************
Optional: promote OUTPUT Datasets.
By default following OUTPUT datasets are promoted automatically.
OUTFOR
OUTSTAT
OUTINFORMATION
OUTMODELINFO
OUTSELECT
If additional OUTPUT datasets that needs to be promoted to global scope, please use vf_promoteCASTable MACRO.
Sample code as follows:
%vf_promoteCASTable(localCASTable = localTableName, globalCASTable = globalTableName);
********************************************************************************************************/