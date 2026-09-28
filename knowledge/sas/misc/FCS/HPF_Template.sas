/*----------------------------------------------------------------------------------------------------------*/
/*                                    BEISPIELCODE HIGH PERFORMANCE FORECASTING (HPF)                       */
/*                                    Vollständige Beschreibung der HPF Syntax unter:                       */
/*         http://support.sas.com/documentation/cdl/en/hpfug/62015/HTML/default/titlepage.htm               */
/*----------------------------------------------------------------------------------------------------------*/



/* Libref für Ausgabe der SAS-Tabellen mit Prognoseergebnissen*/
libname fcs_in "C:\DATEN\RWM";
libname fcs_out "C:\DATEN\RWM";


/* Allgemeine Parameter:
%let _inlib=fcs_in;
%let _outlib=fcs_out;
%let _infile=demand_daily;
%let _interval=week;
%let _timestamp=datum;
%let _depvar=absatz;
%let _inputs=baselevel;
%let _bygroups=series_id_long wochentag;
%let _season=52;
%let _lead=12;
%let _back=0;
%let _holdout=8;
%let _criterion=MAE;
*/


/* Beispielbelegung mit Sashelp Pricedata */
%let _inlib=sashelp;
%let _outlib=fcs_out;
%let _infile=pricedata;
%let _interval=month;
%let _timestamp=date;
%let _depvar=sale;
%let _inputs=price discount;
%let _bygroups=regionname productline productname;
%let _season=12;
%let _lead=12;
%let _back=0;
%let _holdout=8;
%let _criterion=MAE;





%let _alpha=0.05;
%let _outlierdetect=NO;
%let _outliermax=5;
%let _outliersig=0.05;
%let _transform=NONE;
%let _transsig=0.1;
%let _transopt=MEAN;
%let _trenddiff=AUTO;
%let _trendsdiff=AUTO;
%let _trendsiglevel=0.05;
%let _nseason=2;
%let _ntrend=6;
%let _siglevel_arima=0.05;
%let _pmax=5;
%let _qmax=5;
%let _arimamethod=MINIC;
%let _perrormax=5;
%let _identify=BOTH;
%let _noint=;
%let _estmethod=CLS;
%let _armacriterion=SBC;
%let _armasig=0.1;
%let _inputrequire=MAYBE;
%let _modelbasename=M;
%let _exceptions=CATCH;
%let _testinput=BOTH;
%let _esmmethod=BEST;
%let _ecmaxmessage=10;
%let _ecstage=ALL;
%let _ecseverity=NONE;






Proc HPFARIMASPEC 	MODELREPOSITORY = &_outlib..repository SPECNAME=MA_WND_3 SPECLABEL="Moving Average (Smoothing window=3)" SPECTYPE=MOVEAVG; 
FORECAST TRANSFORM = NONE NOINT  P = ( 1 2 3 ) AR = ( 0.3333333333333333 0.3333333333333333 0.3333333333333333 ); 
ESTIMATE NOEST NOSTABLE METHOD=CLS CONVERGE=0.0010  MAXITER=50  DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;


Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=MA_WND_4 SPECLABEL="Moving Average (Smoothing window=4)" SPECTYPE=MOVEAVG; 
FORECAST TRANSFORM = NONE NOINT  P = ( 1 2 3 4) AR = ( 0.25 0.25 0.25 0.25) ; 
ESTIMATE NOEST NOSTABLE METHOD=CLS  CONVERGE=0.0010  MAXITER=50  DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;


Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=MA_WND_5 SPECLABEL="Moving Average (Smoothing window=5)" SPECTYPE=MOVEAVG; 
FORECAST TRANSFORM = NONE NOINT  P = ( 1 2 3 4 5) AR = ( 0.2 0.2 0.2 0.2 0.2) ; 
ESTIMATE NOEST NOSTABLE METHOD=CLS CONVERGE=0.0010 MAXITER=50 DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=MA_WND_6 SPECLABEL="Moving Average (smoothing window=6)" SPECTYPE=MOVEAVG; 
FORECAST SYMBOL = Y TRANSFORM = NONE NOINT P = ( 1 2 3 4 5 6 ) AR = ( 0.1666 0.1666 0.1666 0.1666 0.1666 0.1666 ) ; 
ESTIMATE NOEST NOSTABLE METHOD=CLS CONVERGE=0.0010 MAXITER=50 DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=RANDOMWALK SPECLABEL="Random Walk" SPECTYPE=RANDWALK; 
FORECAST SYMBOL = Y TRANSFORM = NONE NOINT DIF = ( 1 )  ; 
ESTIMATE  METHOD=CLS  CONVERGE=0.0010  MAXITER=50  DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=RANDOMWALKSEASONAL SPECLABEL="Random Walk (Seasonal)" SPECTYPE=RANDWALK; 
FORECAST SYMBOL = Y TRANSFORM = NONE NOINT DIF = ( 1 s )  ; 
ESTIMATE  METHOD=CLS  CONVERGE=0.0010  MAXITER=50  DELTA=0.0010 SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC MODELREPOSITORY = &_outlib..repository SPECNAME=AVERAGE SPECLABEL="Mean" SPECTYPE=ARIMA; 
FORECAST SYMBOL = Y TRANSFORM = NONE  ; 
ESTIMATE METHOD=ML CONVERGE=1.0E-4 MAXITER=150 DELTA=1.0E-4 SINGULAR=1.0E-7  ; 
run;


Proc HPFSELECT MODELREPOSITORY = &_outlib..repository SELECTNAME=NAIVE SELECTLABEL="Naive Models"; 
	SELECT HOLDOUT=0 HOLDOUTPCT=100.0CRITERION=MAE;
	SPEC RANDOMWALK ;
	SPEC RANDOMWALKSEASONAL;
	SPEC AVERAGE;
    SPEC MA_WND_6;
    SPEC MA_WND_5;
    SPEC MA_WND_4;
    SPEC MA_WND_3;
 
run;





/* Diese Prozedur führt die Diagnose für die automatisch system-seitig generierten Modell durch */
proc hpfdiagnose data=&_inlib..&_infile repository=&_outlib..repository  
                    outest=&_outlib..inest 
					outprocinfo=&_outlib..outprocinfo
					seasonality=&_season
                    alpha=&_alpha 
                    criterion=&_criterion
					back=&_back
                    holdout=&_holdout
					minobs=(SEASON=&_nseason TREND=&_ntrend)
                    inselectname=NAIVE 
                    basename=&_modelbasename
                    exceptions=&_exceptions
                    testinput=&_testinput;
transform type=&_transform siglevel=&_transsig transopt=&_transopt; 
trend diff=&_trenddiff sdiff=&_trendsdiff siglevel=&_trendsiglevel;

arimax p=(0:&_pmax) 
       q=(0:&_qmax) 
       method=&_arimamethod 
       identify=&_identify 
       outlier=(detect=&_outlierdetect maxnum=&_outliermax siglevel=&_outliersig) 
       &_noint 
       estmethod=&_estmethod
       criterion=&_armacriterion
	   perror=(0:&_perrormax)
       siglevel=&_armasig; 
esm method=&_esmmethod;

input &_inputs / required=&_inputrequire; 
id &_timestamp interval=&_interval; 
forecast &_depvar; 
by &_bygroups; 
run;


/* Diese Prozedur führt die eigentliche Prognose durch */ 
 proc hpfengine data=&_inlib..&_infile repository=&_outlib..repository inest=&_outlib..inest 
     	          lead=&_lead
				  out=_NULL_
                  outest=&_outlib..outest
				  outfor=&_outlib..outfor
				  outstat=&_outlib..outstat
				  outstatselect=&_outlib..outstatselect
				  outmodelinfo=&_outlib..outmodelinfo
                  errorcontrol=(severity=(&_ecseverity) stage=(&_ecstage) maxmessage=&_ecmaxmessage);
input &_inputs; 
id &_timestamp interval=&_interval;
forecast &_depvar;
by &_bygroups;
run;
