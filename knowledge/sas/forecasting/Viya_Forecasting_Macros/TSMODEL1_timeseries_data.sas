/* Load the Pricedata */

libname myloclib '/opt/sasinside/DemoData/';
libname mycaslib cas caslib=casuser;

%if not %sysfunc(exist(mycaslib.pricedata)) %then %do;
  
 
  data mycaslib.pricedata;
    set myloclib.pricedata;
  run;	 

%end;





/* Accumulate time series at the productname level of the data */



proc tsmodel data  = mycaslib.pricedata
             out   = mycaslib.priceseries_base;
    by regionname productline productname;
    id date interval=month;
    var sale /accumulate=sum;
    var price discount /accumulate=avg;
run;

/* Data step like functionality, adding a new varible, lagprice to the accumulated
	data at the productname level of the timeseries  */


proc tsmodel data       = mycaslib.pricedata
             out        = mycaslib.priceseries_base
             outarray   = mycaslib.newTimeSeries;
    by regionname productline productname;
    id date interval=month;
    var sale /accumulate=sum;
    var price discount /accumulate=avg;
    outarray lagprice;
    submit;             
        *create lag of the price variable;
        do i = 1 to dim(price);
            if i = 1 then lagprice[i] = .;
            else lagprice[i] = price[i-1];
        end;
    endsubmit;
run;

/* Aggregate time series at the productline level of the data */

proc tsmodel data  = mycaslib.pricedata
             out   = mycaslib.price_mid;
    by regionname productline;
    id date interval=month;
    var sale /accumulate=sum;
    var price discount /accumulate=avg;
run;



proc sgpanel data=mycaslib.price_mid noautolegend;
	panelby productline;
	scatter x=date y=sale;
	loess x=date y=sale / smooth=50;
run;


/* optional, promote the data for pickup in other applications running on CAS  


%if not %sysfunc(exist(mycaslib.priceseries_base2)) %then %do;

data mycaslib.priceseries_base2 (promote=yes);
	set mycaslib.priceseries_base;
run;

%end;
*/