/* 	Git: 	https://github.com/sassoftware/sas-viya-forecasting-pipelines/tree/master/Custom modeling nodes
	Paper:	https://www.sas.com/content/dam/SAS/support/en/sas-global-forum-proceedings/2019/3258-2019.pdf
*/
/*
    macro for adding features into input data
        I: &vf_libIn.."&vf_inData"n
        O: &vf_libOut..&vf_tableOutPrefix..&outTblName
*/
%macro fx_prepare_input(outTblName=, byVars=, 
                        trendVariable=, seasonalDummy=, 
                        seasonalDummyInterval=,
                        esmY=, lagXNumber=, lagYNumber=, 
                        holdoutSampleSize=, holdoutSamplePercent=, 
                        criteria=, back=);

    %local filerootpath;
    %let filerootpath = &sas_root_location/misc/codegenscrpt/source/sas;
    %include "&filerootpath./vf_data_prep.sas";
    %let temp_work_location = %sysfunc(pathname(work));
    %include "&temp_work_location./vfDataPrepMacro.sas";

%mend;

/*
    main macro for forecasting using Gradient Boosting Model
*/
%macro gbm_run;

    /*protection against problematic _seasonDummy value*/
    %if (not %symexist(_seasonDummy)) %then 
        %let _seasonDummy=&vf_timeIDInterval;
    %if "&_seasonDummy" eq "" %then 
        %let _seasonDummy = &vf_timeIDInterval;
    %if %sysfunc(INTTEST( &_seasonDummy )) eq 0 %then %do;
        %put Invalid seasonal dummy interval. 
             Use &vf_timeIDInterval instead.;
        %let _seasonDummy = &vf_timeIDInterval;
    %end;
        
    /*parepare input data with extracted feature used for modeling*/
    %fx_prepare_input(outTblName=fxInData, byVars=&vf_byVars, 
                      trendVariable = &_trend,  
                      seasonalDummy = &_seasonDummy, 
                      seasonalDummyInterval = &_seasonDummyInterval,
                      esmY =FALSE, lagXNumber=&_lagXNumber, 
                      lagYNumber=&_lagYNumber, 
                      holdoutSampleSize=&_holdoutSampleSize, 
                      holdoutSamplePercent=&_holdoutSamplePercent, 
                      criteria=RMSE, back=0);
    
    /*Dependent variable transformation if needed*/
    %let targetVar=gbmTargetVar;
    %let predictVar=P_&targetVar;
    data &vf_libOut.."&vf_tableOutPrefix..fxInData"n / 
        SESSREF=&vf_session;
        set &vf_libOut.."&vf_tableOutPrefix..fxInData"n;
        &targetVar = &vf_depVar;
        %if %upcase(&_depTransform) eq LOG %then %do;
          if not missing(&vf_depVar) and &vf_depVar > 0 then 
             &targetVar = log(&vf_depVar);
          else call missing(&targetVar);
        %end;
    run;
    
    /*Train the Gradient Boosting Model*/
    proc gradboost data=&vf_libOut.."&vf_tableOutPrefix..fxInData"n 
                   seed=12345; 
        id &vf_byVars &vf_timeID;                          
        partition rolevar=_roleVar(TRAIN="1" VALIDATE="2" TEST="3");                 
        input &vf_byVars  /level=NOMINAL;
        %if "&vf_indepVars" ne "" %then %do;
          input &vf_indepVars  /level=INTERVAL;
        %end;
        %if %intervalFeatureVarList ne  %then %do;
          input %intervalFeatureVarList /level=INTERVAL;
        %end;
        %if %nominalFeatureVarList ne  %then %do;
          input %nominalFeatureVarList /level=NOMINAL;
        %end;
        target &targetVar / level=interval;
        autotune maxtime=3600
                 tuningparameters=( ntrees(lb=50 ub=500 init=50)) ;
        %if %eval(&_lagYNumber>0) %then %do;
           code file="&temp_work_location./_gbScore.sas";
        %end;
        %else %do;
           output out=&vf_libOut.."scored_gb"n 
                  copyvars=(&vf_byVars &vf_timeID &targetVar);
        %end;
    run;
    
    %if %eval(&_lagYNumber>0) %then %do;
        /*When lagYNumber is non-zero:
          Score the model for the whole dataset with 
          recurrent depedent variable value for the future periods*/
        %let count=%sysfunc(countw(&vf_byVars,%str( )));
        %let lastByVar=%scan(&vf_byVars, &count, %str( ));
        data &vf_libOut.."scored_gb"n /SINGLE=YES;
            set &vf_libOut.."&vf_tableOutPrefix..fxInData"n; 
            by &vf_byVars  &vf_timeID;
            retain copyY . %do i=1 %to &_lagYNumber; 
                               copyY_lag&i. . %end;;
            gbmLastByVar = &lastByVar;
            if first.gbmLastByVar  then do;
                copyY=.; 
                %do i=1 %to &_lagYNumber; copyY_lag&i.=.; %end;
            end;
            %do i=&_lagYNumber  %to 1 %by -1;
                %if &i eq 1 %then %do;
                    if not missing(copyY) then copyY_lag1=copyY;
                %end;
                %else %do;
                    if not missing(copyY_lag%eval(&i -1)) then 
                      copyY_lag&i = copyY_lag%eval(&i -1);
                %end;
            %end;
            %do i=1 %to &_lagYNumber; _lagY&i = copyY_lag&i.; %end;
            %include "&temp_work_location./_gbScore.sas";
            if &vf_timeID >= &vf_horizonStart then copyY = &predictVar;
            else copyY = &targetVar;
            drop copyY %do i=1 %to &_lagYNumber; copyY_lag&i.  %end;;
        run;
    %end;
    
    /*prepare the required output tables*/
    data &vf_libOut.."&vf_outFor"n;
       set &vf_libOut.."scored_gb"n;
       actual = &targetVar;
       predict = &predictVar;
       %if %upcase(&_depTransform) eq LOG %then %do;
          if not missing(actual) then actual = exp(actual);
          if not missing(predict) then predict = exp(predict);
       %end;
       %if "&vf_allowNegativeForecasts" eq "FALSE" %then %do;
          if not missing(predict) and predict < 0 then predict = 0;
       %end;
       %if &targetVar ne &vf_depVar or &predictVar ne predict %then %do;
          drop &targetVar  &predictVar;
       %end;
    run;    

%mend;  

/*invoke the main macro */
%gbm_run;

