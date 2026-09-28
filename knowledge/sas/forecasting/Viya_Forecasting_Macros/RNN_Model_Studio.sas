/* https://communities.sas.com/t5/SAS-Communities-Library/How-to-incorporate-Recurrent-Neural-Networks-in-your-SAS-Visual/ta-p/770711
*/

/*-------------------------------------------------------------------
 * Forecast at a particular level
 *-----------------------------------------------------------------*/

*request ODS output outInfo and name it as sforecast_outInformation;
ods output OutInfo = sforecast_outInformation;

*run TSMODEL to generate forecasts;

proc tsmodel data = &vf_libIn.."&vf_inData"n
          logcontrol = (error = keep warning = keep)
          /*outSum = &outsum
          outlog = &outlog*/
          %if "&vf_inEventObj" ne "" %then %do;
             inobj = (&vf_inEventObj)
          %end;
          outobj = (   
          			   outfor  = &vf_libOut.."&vf_outFor"n (replace=YES)
                       outstat = &vf_libOut.."&vf_outStat"n (replace=YES)
                       outSelect = &vf_libOut.."&vf_outSelect"n (replace=YES)
                       outmodelinfo = &vf_libOut.."&vf_outModelInfo"n (replace=YES)
                       of  = &vf_libOut..rnnfor (replace=YES)
                       ofs = &vf_libOut..rnnstat (replace=YES)
                       ofopt =&vf_libOut..ex1outtnfopt (replace=YES)
                       
                       )
          outlog  = &vf_libOut.."&vf_outLog"n
          outarray = &vf_libOut..outarray 
          errorstop = YES  
          lead = &vf_lead.
          ;
          
    *define time series ID variable and the time interval;
    id &vf_timeID interval = &vf_timeIDInterval
                  setmissing = &vf_setMissing trimid = LEFT;

    *define time series and the corresponding accumulation methods;
    %vf_varsTSMODEL;
	outarray rfor lfor ufor efor stdefor;

    *define the by variables if exist;
    %if "&vf_byVars" ne "" %then %do;
       by &vf_byVars;
    %end;

    *using the ATSM, TNF and TSM packages;
    require tnf;
    require atsm;
    require tsm;

    *starting user script;
    submit;

        declare object f(TNF);
        declare object of(OUTTNF);
        declare object ofs(OUTTNFSTAT);
        declare object ofopt(OUTTNFOPT);
        rc = f.Initialize();
        rc = f.setTarget(&vf_depVar.);
        rc = f.SetOption(
                        'RNNTYPE','LSTM',
                        'NINPUT', 3,
                        'NLAYER', 4,
                        'NNEURONH',30,
                        'NHOLDOUT',3,
                        'NORMALIZE', 'STD',
                        'POSTTRAIN', 'YES',
                        'LEAD', &vf_lead.,
                        'SEED', 12345
                        );
      rc = f.SetOptimizer(
                        'ALGORITHM','ADAM',
                        'LEARNINGRATE', 0.1,
                        'BETA1', 0.8,
                        'BETA2', 0.9,
                        'LEARNINGPOLICY', 'STEP',
                        'STEPSIZE', 5,
                        'GAMMA', 0.5,
                        'STAGNATION', 20,
                        'MINIBATCHSIZE',8,
                        'WARMUPEPOCHS',15,
                        'MAXEPOCHS', 100
                        );
      rc = f.Run();if rc < 0 then stop;
      rc = f.GetForecast('FORECAST', rfor);
      rc = f.GetForecast('RESIDUAL', efor);
      rc = f.GetForecast('STDERR', stdefor);
      rc = f.GetForecast('UPPER', ufor);
      rc = f.GetForecast('LOWER', lfor);
      rc = of.Collect(f);if rc < 0 then stop;
      rc = ofs.Collect(f);if rc < 0 then stop;
      rc = ofopt.Collect(f);if rc < 0 then stop;


	/* Create external model specification for the RNN model */ 
	declare object rExmSpec(EXMSPEC); 
	rc = rExmSpec.open(); 
	rc = rExmSpec.setOption('ERROR','efor');
	rc = rExmSpec.setOption('STDERR','stdefor'); 
	rc = rExmSpec.setOption('LOWER','lfor');
	rc = rExmSpec.setOption('UPPER','ufor');	
	rc = rExmSpec.setOption('PREDICT','rfor'); 
	rc = rExmSpec.close();


	declare object dataFrame(tsdf);
        declare object diagnose(diagnose);
        declare object diagSpec(diagspec);
        declare object inselect(selspec); 
        declare object forecast(foreng);
        
        /*initialize the tsdf object and assign the time series roles: setup dependent and independent variables*/
        rc = dataFrame.initialize();
        rc = dataFrame.AddSeries(rfor);
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

        rc = diagnose.Run();
        ndiag = diagnose.nmodels();                                 
            
        /*Run model selection and forecast*/                     
        rc = inselect.Open(1); 
        rc = inselect.AddFrom(rExmSpec);
        rc = inselect.close(); 
        
        /*initialize the foreng object with the dataframe result and run model selecting and generate forecasts;*/         
        rc = forecast.initialize(dataFrame);

	/* Run the following line of code to diagnose SAS models along with RNN models */
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
