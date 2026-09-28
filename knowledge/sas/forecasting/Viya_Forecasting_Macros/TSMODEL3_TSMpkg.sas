/* Load the Pricedata */

libname myloclib '/opt/sasinside/DemoData/';
libname mycaslib cas caslib=casuser;

%if not %sysfunc(exist(mycaslib.pricedata)) %then %do;
  
  data mycaslib.pricedata;
    set myloclib.pricedata;
  run;	 

%end;

/* create a user specified model in TSMODEL using the TSM package */

proc tsmodel data   = mycaslib.pricedata
             outobj = (
                       outFor  = mycaslib.outFor
                       outEst  = mycaslib.outEst
                       outspec = mycaslib.outspec
                       );
    id date interval=month;
    var sale /acc = sum;
    var price/acc = avg;

    *use TSM package;
    require tsm;
    submit;
        *declare TSM objects;
        declare object myarima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);
        declare object outspec(tsmspec);

        array diff[1]/nosymbols (12); 
        array ar[1]/nosymbols (12);
       
        /** next steps specify arima model parameters arima (0,0,0)(1,1,0)s with x(1) **/
        rc = myarima.open();
        
        *usage: rc = ARIMASpec.SetDiff(DiffArray[,NDiff]);
        rc = myarima.setDiff(diff);
        
        *usage: rc = ARIMASpec.AddARPoly(OrderArray[,NOrder,Seasonal,CoeffArray]);
        rc = myarima.addARPoly(ar,1,0);

        *usage: rc = ARIMASpec.AddTF(XName[,Delay,DiffArray,NDiff]);
        rc = myarima.addTF('price', 0, diff);
        
        rc = myarima.setOption('method', 'ml');
        rc = myarima.close();

        *set options: y and x variables, lead, model;
        rc = tsm.initialize(myarima);
        rc = tsm.setY(sale);
        rc = tsm.addX(price);
        rc = tsm.setOption('lead',0);
        rc = tsm.run();

        *collect the estimates into object called outest;
        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
    endsubmit;
run;

proc print data=mycaslib.outest (keep=_modelvar_ _component_ _parm_ _lag_ _est_ _pvalue_);
run;

proc print data=mycaslib.outspec (keep=_modelclass_ _status_ _spec_); 
run;

proc sgplot data=mycaslib.outfor;
       histogram error;
run;


