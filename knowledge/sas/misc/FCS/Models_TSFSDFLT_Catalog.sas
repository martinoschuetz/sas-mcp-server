/*- mean -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=mean;
forecast symbol=y;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- linear trend -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=lineartrend;
forecast symbol=y;
input symbol=lineartrend;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- simple exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=simple;
esm method=simple;
run;
/*- double(brown) exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=double;
esm method=double;
run;
/*- linear(holt) exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=linear;
esm method=linear;
run;
/*- damped trend exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=damptrend;
esm method=damptrend;
run;
/*- seasonal exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=seasonal;
esm method=seasonal;
run;
/*- winters multiplicative -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=winters;
esm method=winters;
run;
/*- winters additive -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=addwinters;
esm method=addwinters;
run;
/*- random walk with drift -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=rwwd;
forecast symbol=y dif=(1);
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- Airline Model -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=airline;
forecast symbol=y dif=(1,12) q=(1)(12) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA000011noint;
forecast symbol=y dif=(12) q=(12) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(0,1,1)(1,0,0)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA011100noint;
forecast symbol=y p=(12) dif=(1) q=(1) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(2,0,0)(1,0,0)s -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA200100;
forecast symbol=y p=(1,2)(12);
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(0,1,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA012011noint;
forecast symbol=y dif=(1,12) q=(1,2)(12) noint;
run;
/*- ARIMA(2,1,0)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA210011noint;
forecast symbol=y p=2 dif=(1,12) q=(12) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(0,2,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA022011noint;
forecast symbol=y dif=(1,2,12) q=(2)(12) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- ARIMA(2,1,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=ARIMA212011noint;
forecast symbol=y p=2 dif=(1,12) q=(1,2)(12) noint;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log mean -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logmean;
forecast symbol=y transform=log;
run;
/*- log linear trend -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=loglineartrend;
forecast symbol=y transform=log;
input symbol=lineartrend;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log simple exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logsimple;
esm method=simple  transform=log;
run;
/*- log double(brown) exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logdouble;
esm method=double  transform=log;
run;
/*- log linear(holt) exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=loglinear;
esm method=linear transform=log;
run;
/*- log damped trend exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logdamptrend;
esm method=damptrend transform=log;
run;
/*- log seasonal exponential smoothing -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logseasonal;
esm method=seasonal transform=log;
run;
/*- log winters multiplicative -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logwinters;
esm method=winters transform=log;
run;
/*- log winters additive -*/
proc hpfesmspec modelrepository=sashelp.hpfdflt
                specname=logaddwinters;
esm method=addwinters transform=log;
run;
/*- log random walk with drift -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logrwwd;
forecast symbol=y dif=(1) transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log Airline Model -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logairline;
forecast symbol=y dif=(1,12) q=(1)(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA000011noint;
forecast symbol=y dif=(12) q=(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(0,1,1)(1,0,0)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA011100noint;
forecast symbol=y p=(12) dif=(1) q=(1) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(2,0,0)(1,0,0)s -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA200100;
forecast symbol=y p=(1,2)(12) transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(0,1,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA012011noint;
forecast symbol=y dif=(1,12) q=(1,2)(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(2,1,0)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA210011noint;
forecast symbol=y p=2 dif=(1,12) q=(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(0,2,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA022011noint;
forecast symbol=y dif=(1,2,12) q=(2)(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- log ARIMA(2,1,2)(0,1,1)s NOINT -*/
proc hpfarimaspec modelrepository=sashelp.hpfdflt
                  specname=logARIMA212011noint;
forecast symbol=y p=2 dif=(1,12) q=(1,2)(12) noint transform=log;
estimate method=ml converge=.0001 delta=.0001 maxiter=150;
run;
/*- TSFS model selection list -*/
proc hpfselect modelrepository=sashelp.hpfdflt
               selectname=tsfsselect
               selectlabel="Default TSFS model selection list";
spec 
     mean lineartrend simple double linear damptrend seasonal winters addwinters
     rwwd airline arima000011noint arima011100noint 
     arima200100 arima012011noint arima210011noint
     ARIMA022011noint ARIMA212011noint
     logmean loglineartrend 
     logrwwd logairline
     logsimple logdouble loglinear logdamptrend logseasonal logwinters logaddwinters
     logarima000011noint logarima011100noint 
     logarima200100 logarima012011noint logarima210011noint
     logARIMA022011noint logARIMA212011noint   
     ;
select criterion=rmse;
run;