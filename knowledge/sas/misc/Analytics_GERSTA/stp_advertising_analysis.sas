/*Stored Process Beispiel */

%stpbegin;
libname a "D:\DATEN\QUeLLEN";
ods listing close;
ods html;

%global tvr;
%global addecay;
%global spot;
%global werbekosten;
/*
%let addecay=0.75;
%let werbekosten=15000;
%let spot=17145;
%let tvr=%eval(&werbekosten/300);
%put &tvr;
*/
data a.input;
  retain adstock 0;
  set a.series_final;j=_n_;
   if j in (20,65,100) then adstock=&addecay*tvr; else adstock=&addecay*adstock;format adstock 8.2;
   label adstock='Adstock' sales ='Umsatz';
   drop j;
run;


PROC AUTOREG DATA = a.input outest=a.parameters;
	MODEL sales = adstock tvr / METHOD=ML MAXITER=50 NLAG=1 ;
	ODS SELECT  Autoreg.Model1.FinalModel.ParameterEstimates
                Autoreg.Model1.FinalModel.FitSummary;

	run;

DATA _NULL_;
  set a.parameters;
  call symput ("intercept",intercept);
  call symput ("p_adstock",adstock);
  call symput ("p_tvr", tvr);
run;

%put &intercept;
%put &p_adstock;
%put &p_tvr;



goptions device=activex;
axis2 label=("Umsatz" ) order=(60000 to 130000 by 10000);
axis1 label=('Werbe-Effekt');
axis3 label=('Kalenderdatum');
symbol1 color=blue
        interpol=join
        value=none
        height=1;
symbol2 color=red
        interpol=join
        value=none
		height=1;
symbol3 color=green
        interpol=join
        value=none
		height=1;


legend1 across=2 origin=(0,0) mode=share  label=(position=top justify=left
             'Legende')
       shape=bar(9,4);

data a.plotdata;
  set a.input;


  adeffect=&p_adstock*adstock +&p_tvr*tvr;
  netsales=sales-adeffect;
  label sales='Umsatz (gesamt)' 
        adeffect='Werbeeffekt' 
        netsales ='Umsatz (bereinigt um Werbeeffekt)';

  run;


proc forecast data=a.plotdata interval=week lead=24
                 method=winters seasons=52 out=a.out outfull outest=a.est; 
      id week; 
      var netsales; 
      
   run;

data a.plotdata2;
   merge a.plotdata a.out (where=(_TYPE_='FORECAST'));
   by week;
   drop _TYPE_ _LEAD_;
   if week=&spot then tvr=&tvr; else tvr=0;

run;

data a.plotdata2;
   retain adstock2 0 ;
   set a.plotdata2;
   if week=&spot then adstock2=&addecay*tvr; 
   else if week>&spot then adstock2=&addecay*adstock2; 
   if missing(adstock) then adstock=adstock2;
   if missing(date) then date=week;
   drop adstock2;
   if missing(adeffect) then do;
      adeffect=&p_adstock*adstock +&p_tvr*tvr;
	  sales=netsales+adeffect;
	  end;
   
run;


title1 "Zeitreihendiagramm für Werbewirkungsprognose";
proc gplot data=a.plotdata2;
plot  (sales netsales) *date/ overlay vaxis=axis2 href='04OCT2006'd chref=black legend=legend1;
run;


quit;

proc means data=a.plotdata2 (where=(date>='04OCT2006'd)) noprint;
     output out=a.summary sum(adeffect)=summe;
run;

data a.summary;
  set a.summary;
  Werbedruck=&werbekosten;
  tvr=&tvr;
  gewinn=summe-werbedruck;
  roi=gewinn/werbedruck;
  label summe='Werbeeffekt' werbedruck='Werbeaufwand in €'
        roi ='Return on Investment' gewinn='Gewinn';
  format summe werbedruck gewinn eurox13. roi percent8.2;
  run;

title "Übersicht für Return on Investment";
proc print data=a.summary label noobs;
 var summe werbedruck gewinn roi;
run;

title "Prognostizierte Umsätze";
proc print data=a.plotdata2 (where=(date>='04OCT2006'd))label noobs;
 var week sales;
 format sales eurox13.;
run;
ODS HTML close;
ods listing;

%stpend;