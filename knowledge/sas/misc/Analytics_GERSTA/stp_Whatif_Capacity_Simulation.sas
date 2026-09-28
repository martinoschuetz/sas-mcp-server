*  Begin EG generated code (do not edit this line);
*
*  Stored Process regististriert durch 
*  Enterprise Guide Stored Process Manager v4.1
*
*  ====================================================================
*  Stored Process-Name: Whatif-Simulation
*
*  Beschreibung: Whatif-Analyse für Kapazitätsplanung
*  ====================================================================
*
*  Verzeichnis der Stored Process-Parameter:
*  ____________________________________
*  VL_BUDGET
*       Typ: Float
*      Gruppe: > Allgemein
*      Etikett: Budget
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 400
*       Beschr.: Advertising Budget (in Thousand Euro)
*  ____________________________________
*  VL_CAMPTYPE
*       Typ: String
*      Gruppe: > Allgemein
*      Etikett: Type of Campaign
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: Type A
*       Beschr.: Type of Campaign
*  ____________________________________
*  VL_EOM_FLAG
*       Typ: Integer
*      Gruppe: > Allgemein
*      Etikett: EOM Flag
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 0
*       Beschr.: End-Of-Month Flag (1=Yes, 0 = No)
*  ____________________________________
*  VL_MONTH
*       Typ: String
*      Gruppe: > Allgemein
*      Etikett: Month
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: DEC
*       Beschr.: Month of the year
*  ____________________________________
*  VL_PCT_MAIL
*       Typ: Float
*      Gruppe: > Allgemein
*      Etikett: Percent Mail
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 12.0
*       Beschr.: Percent E-Mail Mailout
*  ____________________________________
*  VL_SEGMENT
*       Typ: String
*      Gruppe: > Allgemein
*      Etikett: Customer Segment
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: Consumer
*       Beschr.: Customer Segment
*  ____________________________________
*  VL_TRANSTYPE
*       Typ: String
*      Gruppe: > Allgemein
*      Etikett: Transaction Type
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: TR-0001
*       Beschr.: Type of Transaction
*  ____________________________________
*  VL_TRENDCYCLE
*       Typ: Float
*      Gruppe: > Allgemein
*      Etikett: Base Demand Forecast
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 1200
*       Beschr.: Baseline Demand Forecast
*  ____________________________________
*  VL_VOLUME
*       Typ: Float
*      Gruppe: > Allgemein
*      Etikett: Volume
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 4000
*       Beschr.: Campaign Volume (in Thousand)
*  ____________________________________
*  VL_WEEKDAY
*       Typ: String
*      Gruppe: > Allgemein
*      Etikett: Day of Week
*       Attr: Sichtbar, Modifizierbar, Erforderlich
*    Standard: 1. So
*       Beschr.: Day of Week
*  ____________________________________
*;


*ProcessBody;

%global VL_BUDGET
        VL_CAMPTYPE
        VL_EOM_FLAG
        VL_MONTH
        VL_PCT_MAIL
        VL_SEGMENT
        VL_TRANSTYPE
        VL_TRENDCYCLE
        VL_VOLUME
        VL_WEEKDAY;
*  End EG generated code (do not edit this line);

*Processbody;
%let _ODSSTYLE=normal;
%stpbegin;
ods html;

%global vl_transtype;
%global vl_budget;
%global vl_camptype;
%global vl_pct_mail;
%global vl_segment;
%global vl_volume;
%global vl_weekday;
%global vl_month;
%global vl_eom_flag;
%global vl_trendcycle;

/*
data _null_;
  set fcslib.initial;
  if _n_=1 then do;
  call symput("vl_transtype",transtype);
  call symput("vl_budget",budget);
  call symput("vl_pct_mail",pct_mail);
  call symput("vl_segment",segment);
  call symput("vl_volume",volume);
  call symput("vl_weekday",weekday);
  call symput("vl_month",month);
  call symput("vl_eom_flag",eom_flag);
  
  end;
run;
*/


data tmp;
 set fcslib.initial;
 transtype="&vl_transtype";
 budget=&vl_budget;
 camptype="&vl_camptype";
 pct_mail=&vl_pct_mail;
 volume=&vl_volume;
 segment="&vl_segment";
 weekday="&vl_weekday";
 month="&vl_month";
 eom_flag=&vl_eom_flag;
 trendcycle_cpu=&vl_trendcycle;

%include "D:\Daten\MINING\KAPPLAN\Workspaces\EMWS\Score\PATHPUBLISHSCORECODE.sas";

uplift_factor=EM_PREDICTION;

prediction=uplift_factor*trendcycle_cpu;

format uplift prediction 8.3;

label transtype='Transaction Type'
      budget='Advertising Budget'
	  camptype='Campaign Type'
	  pct_mail='Percent mailout'
	  volume='Volume'
	  segment='Segment'
	  weekday='Day of Week'
	  month='Month'
	  eom_flag='End-of-the-Month-Status'
	  trendcycle_cpu='Demand Forecast'
	  prediction='Predicted Demand'
	  uplift_factor='Uplift Factor'
;
 run;

data tmp2;
  set tmp;
  do i=1 to 21;
  factor=0.89+(i/100);
  output;
  end;
run;

data tmp3;
  set tmp2(in=a) tmp2(in=b) tmp2(in=c);
  if a then do; 
    simrun='Volume';
	volume=volume*factor;
  end;
  else if b then do;
    simrun='Budget';
    budget=budget*factor;
  end;
  else if c then do;
    simrun='Base';
	trendcycle_cpu=trendcycle_cpu*factor;
   end;

  
run;







data tmp4;
 set tmp3;
  
%include "D:\Daten\MINING\KAPPLAN\Workspaces\EMWS\Score\PATHPUBLISHSCORECODE.sas";

uplift_factor=EM_PREDICTION;

prediction=uplift_factor*trendcycle_cpu;

format uplift_factor prediction 8.3;

label transtype='Transaction Type'
      budget='Advertising Budget'
	  camptype='Campaign Type'
	  pct_mail='Percent mailout'
	  volume='Volume'
	  segment='Segment'
	  weekday='Day of Week'
	  month='Month'
	  eom_flag='End-of-the-Month-Status'
	  trendcycle_cpu='Base Demand Forecast'
	  prediction='Predicted Demand'
	  uplift_factor='Uplift Factor'
;
run;


title "Simulation Results";
 proc print data=tmp noobs label;
  var transtype budget camptype pct_mail volume segment weekday month eom_flag trendcycle_cpu uplift_factor prediction;

run;
GOPTIONS xpixels=600 ypixels=480;

SYMBOL1 INTERPOL=JOIN HEIGHT=10pt VALUE=NONE CV=BLUE LINE=1 WIDTH=2	;
Axis1 STYLE=1 WIDTH=1 MINOR=NONE;
Axis2 STYLE=1 WIDTH=1 MINOR=NONE;
TITLE;
TITLE1 "Sensitivity Analysis for Budget";
PROC GPLOT DATA = tmp4 (where=(simrun="Budget"));
PLOT prediction * budget  /VAXIS=AXIS1 HAXIS=AXIS2 FRAME LHREF=1 CHREF=BLACK HREF=&vl_budget;
run;
TITLE1 "Sensitivity Analysis for Volume";
PROC GPLOT DATA = tmp4 (where=(simrun="Volume"));
PLOT prediction * volume /VAXIS=AXIS1 HAXIS=AXIS2 FRAME LHREF=1 CHREF=BLACK HREF=&vl_volume;
run;
TITLE1 "Sensitivity Analysis for Baseline Demand";
PROC GPLOT DATA = tmp4 (where=(simrun="Base"));
PLOT prediction * trendcycle_cpu /VAXIS=AXIS1 HAXIS=AXIS2 FRAME LHREF=1 CHREF=BLACK HREF=&vl_trendcycle;
run;


ods html close;
%stpend;

*  Begin EG generated code (do not edit this line);
*';*";*/;run;

*  End EG generated code (do not edit this line);
