/* Sample program for ensmble modeling (i.e., create a weighted forecast from two independent forecast runs
where weights are automatically determined using regression with restricted parameter values (via PROC MODEL) 


Note that I use the pricedata sample data set (located in SASHELP library that ships with the software 
Also note that I use two runs of HPFDIAGNOSE and HPFENGINE to create two independent forecast runs(
first one uses ARIMA, second uses exponential smoothing type family) and put results into respective OUTFOR table. 
Alternatively, you could set up two Forecast Studio projects and merge the results. In that case you would only 
need to look at code section starting with PROC MODEL. */

/* In this run I will automatically determine the best model of type ARIMA  */
proc hpfdiagnose data=sashelp.pricedata repository=work.myrep outest=work.est1;
	forecast sale;
	id date interval=month;
	by regionname productline productname;
	arimax;
run;

/* The model parameters in table est1 will be used to generate the second forecast. Results will be put into table Outfor1 */
proc hpfengine data=sashelp.pricedata 
	repository=work.myrep 
	inest=work.est1 
	lead=12 
	outfor=outfor1;
	forecast sale;
	id date interval=month;
	by regionname productline productname;
run;

/* In this run I will automatically select best model of type exponential smoothing */
proc hpfdiagnose data=sashelp.pricedata 
	repository=work.myrep
	outest=work.est2;
	esm;
	id date interval=month;
	forecast sale;
	by regionname productline productname;
run;

/* The model parameters in table est2 will be used to generate the second forecast. Results will be put into table Outfor2 */
proc hpfengine data=sashelp.pricedata
	repository=work.myrep 
	inest=work.est2
	lead=12 
	outfor=outfor2;
	id date interval=month;
	forecast sale;
	by regionname productline productname;
run;

/* I merge the results from the two forecast runs */
proc sql;
	create table merged_forecasts as select
		a.regionname,
		a.productline,
		a.productname,
		a.date,
		a.actual,
		a.predict as predict1,
		b.predict as predict2 
	from outfor1 as a inner join outfor2 as b on
		(a.regionname		= b.regionname and
		a.productline 		= b.productline and
		a.productname		= b.productname and
		a.date				= b.date)
	order by a.regionname, a.productline, a.productname, a.date;
quit;

/* In this section I use PROC MODEL to run a regression to compute weights for individual prediction values  */

/* Details on PROC MODEL Syntax can be found at: 
http://support.sas.com/documentation/cdl/en/etsug/63348/HTML/default/viewer.htm#model_toc.htm */
proc model data=merged_forecasts out=results(drop=_ESTYPE_ _TYPE_ _WEIGHT_ rename=(ACTUAL=FINALPREDICT)) noprint;
	by regionname productline productname;
	id date;
	actual=a1*predict1+a2*predict2; /* This is the model equation with weights of a1 and a2 */

	/* To control iteration process I submit start values of 0.5, respectively (in other words, both predicted values will assigend a weight of 50% )*/
	fit actual start=(a1=0.5, a2=0.5) / startiter ols converge=0.05 outpredict outest=weights;
	restrict a1+a2=1;  /* Restrict statement ensures that weights sum up to 100% */
	bounds a1>0.01,a2>0.01; /* Via bounds statement I can control the value range of parameters, e.g., enforce them to be non-negative or even be at least 0.01*/
run;

/* Here I show the table to computed weights */
proc print data=weights noobs;
	title "Weights";
	var regionname productline productname a1 a2;
run;

/* Hier I show the individual forecasts and the combined ensemble forecast (only for forecast horizon, starting in January 2003) */
proc print data=results(where=(date>='01JAN2003'd)) noobs;
	title "Ensemble Forecasts ";
	var regionname productline productname date finalpredict predict1 predict2;
run;