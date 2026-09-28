/* This SAS program includes a High Performance Forecasting stored process     */
/* to be executed under Microsoft Excel using the SAS Add-In for Microsoft     */
/* Office. Please see accompanying Word document how to set up and register    */
/* the stored process.                                                         */
/*                                                                             */
/* It is assumed that you are extracting all necessary files to the default    */
/* locations on C drive. If this is not the case, please adjust the path names */
/* in the libname and ODS statements at the beginning of the code.             */
/*                                                                             */
/* To run this program in a SAS session (not as a stored process), modify the  */
/* the program as follows:                                                     */
/*   1. Uncomment the macro assignment statements at the end of this section.  */
/*   2. Comment the stored process macro lines %stpbegin and %stpend.          */
/*                                                                             */
/* Stefan Ahrens, SAS Germany, 03/22/2005                                      */
/*                                                                             */
/* Macro variable assignment section (uncomment if code is NOT used as stp):   */
/*
%let statistic=MAPE;
%let variable=Sales;
%let lead=7;
%let product=Business; 
*/


libname hpf "C:\Daten\STP\HPF";
ods html body='C:\Daten\STP\HPF\hpf_body.htm'
         frame='C:\Daten\STP\HPF\hpf_frame.htm'
         contents='C:\Daten\STP\HPF\hpf_contents.htm'
		 style=sasweb;

proc hpfdiagnose data=hpf.database (where=(product IN ("&product.","&product1.","&product2.","&product3.")))
  outest=hpf.prel_estimates
  modelrepository=hpf.mymodels
  inevent=hpf.events
  criterion=&statistic
  print=all;
  id date interval=day notsorted; 
  by product;
  event 
       newyear 
       easter
	   labor_day
       christmas
	   promotion2_2002
	   promotion1_2003
	   promotion2_2003
	   promotion1_2004
	   promotion2_2004
	   promotion1_2005;
  forecast &variable;
  esm;
  arimax;
  automodel;
run;

ods html close;

%stpbegin;


%Macro setplotparams;
  %global axislabel; 
  %If &variable = Calls %Then %Let axislabel='Call Volume (number of minutes)';
  %else %if &variable = Sales %then %let axislabel='Sales Amount in €';
%Mend setplotparams;


%Macro setplottitle;
  %global plotheader;
  %If &variable = Calls %Then %Let plotheader=Forecast of Call Volume;
  %else %if &variable = Sales %then %let plotheader=Forecast of Sales;
%Mend setplottitle;

%setplottitle
run;

%setplotparams
run;
  

proc hpfengine data=hpf.database (where=(product IN ("&product.","&product1.","&product2.","&product3.")))
   lead=&lead. 
   inest=hpf.prel_estimates
   outest=hpf.final_estimates
   INEVENT=hpf.events
   modelrepository=hpf.mymodels 
   out=_null_ 
   outfor=hpf.forecast 
   outstat=hpf.statistics;
   id date interval=day; 
   by product;
   forecast &variable / task=select;
run;



symbol1 color=blue
        interpol=join
        value=none
		line=1
        height=1;
symbol2 color=red
        value=none
		line=2
		interpol=join
        height=1;
symbol3 color=green
        interpol=join
        value=none
		line=1
        height=1;
symbol4 color=red
        value=none
		interpol=join
		line=2
        height=1;

legend1 down=2 across=2 position=(bottom center outside)    
        label=('Legend:');

axis1 order=('01Aug2004'd to '01Mar2005'd by month)
      label=('Date')
      minor=none
      width=1;

axis2 label=(&axislabel)
      width=1;


data hpf.plotdata;
   set hpf.forecast;
   if date gt '01Aug2004'd;
   format actual predict lower upper commax10.0;
   label actual='Actual values'
         predict='Predicted values'
		 lower='Lower 95% Confidence Limit'
		 upper='Upper 95% Confidence Limit';
   format date mmddyy8.;
run;

data hpf.fitdata;
   set hpf.statistics;
   keep n rsquare rmse mape aic sbc product;
   format rsquare rmse mape aic sbc 8.3;
run;

goptions device=activex;
ods html style=seaside; 

title "&Plotheader for &lead days";


proc gplot data=hpf.plotdata (where=(product IN ("&product.","&product1.","&product2.","&product3.")));
    by product;
    plot (  actual lower predict upper ) * date / overlay 
        legend=legend1
        haxis=axis1 autohref href='01Feb2005'd chref=black cautohref=lightgrey
        vaxis=axis2 autovref;
run;
quit;

proc print data=hpf.fitdata (where=(product IN ("&product.","&product1.","&product2.","&product3."))) noobs label; 
var rsquare rmse mape aic sbc; 
title "Selected Fit Statistics of Forecast Model";
by product;
run;

footnote "Report generated on  %SYSFUNC(DATE(),WORDDATE18.) at %SYSFUNC(TIME(),TIMEAMPM8.)";

proc print data=hpf.plotdata (where=((date gt '22Jan2005'd) AND (product IN ("&product.","&product1.","&product2.","&product3.")))) noobs label; 
var  date actual predict lower upper; 
title "Listing of Forecast Values";
by product;
format date date9.;
format actual predict lower upper 20.2;
run;


ods html close;

%stpend;

