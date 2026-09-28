/* Load the Pricedata */

libname myloclib '/opt/sasinside/DemoData/';
libname mycaslib cas caslib=casuser;

%if not %sysfunc(exist(mycaslib.pricedata)) %then %do;
  
 data mycaslib.pricedata;
    set myloclib.pricedata;
  run;	 

%end;


/* automatic model generation, selection and forecasting using the ATSM package
	in TSMODEL
*/

proc tsmodel data   = mycaslib.pricedata
             outobj = (
                       outFor  = mycaslib.outFor /* output object tied to the outfor table in the caslib*/
                       outEst  = mycaslib.outEst
                       outStat = mycaslib.outStat
                       );
    by regionname productline productname;
    id date interval=month;
    var sale /acc = sum;
    var price/acc = avg;

    *use the ATSM package;
    require atsm;
    submit;
        *declare ATSM objects;
        declare object dataFrame(tsdf);
        declare object my_diag(diagnose);
        declare object my_diagSpec(diagspec);
        declare object forecast(foreng);
        declare object outFor(outfor); /* output object is declared, and tied to a type */
        declare object outEst(outest);
        declare object outStat(outstat);

        *setup dependent and independent variables;
        rc = dataFrame.initialize();
        rc = dataFrame.addY(sale);
        rc = dataFrame.addX(price);

		*setup time series diagnose specifications;
       	rc = my_diagSpec.open();
        rc = my_diagSpec.setArimax('identify', 'both');
        rc = my_diagSpec.setEsm('method', 'best');
        rc = my_diagSpec.close();

		*diagnose time series and generate the candidate model
			 specifications;
        rc = my_diag.initialize(dataFrame);
        rc = my_diag.setSpec(my_diagSpec);
        rc = my_diag.run();

		*run model selection and generate forecasts;
        rc = forecast.initialize(my_diag);
        rc = forecast.setOption('lead', 12, 'holdoutpct', 0.1);
        rc = forecast.run();

		*collect forecast results;
        rc = outFor.collect(forecast);
        rc = outEst.collect(forecast);
        rc = outStat.collect(forecast);
    endsubmit;
run;

/* create a histogram of rmse for all 17 forecast models */

proc sgplot data=mycaslib.outstat;
histogram rmse;
run;



proc sgplot data=mycaslib.outfor (where=(regionName='Region3' 
                              and productLine='Line4' and productName='Product13'));
               band x=date lower=lower upper=upper;
               series x=date y= predict;
               scatter x=date y=actual;
               /* flag the last observation on the response (sale) in the series */
               refline '01DEC02'd / axis=x lineattrs=(color=red);
run;


