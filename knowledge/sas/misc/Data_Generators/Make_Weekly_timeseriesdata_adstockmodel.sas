/* Test generiere Wochendaten für Abverkäufe */
libname a "D:\daten\QUELLEN";
ods listing close;
ods html;

%let level=1000;
%let amplitude=20;
%let shift=20;
%let frequenz=(2*3.14159265358979)/(365.25/7);
%let coeff=0.5;
%let resid=60;
%let trendfactor=1.1;
%let addecay=0.75;


data series;
   
   do i=1 to 10000;
       i=i+7;
	   j=int((i-1)/20)+1;
	   date=today()-(10000-i);
     output;
   end;
   
   format date date9.;

   

run;

data series;
   set series;
   retain autocorr 0;
   weekly=&amplitude*cos(&frequenz*(_N_-&shift))+&amplitude*sin(&frequenz*(_N_-&shift));
   random=rannor(1)*&resid;
   trend=(i**&trendfactor)/50;
   sales=&coeff*(&level+trend+weekly+random)+(1-&coeff)*autocorr;output;
   autocorr=sales;
 
run;

data series;
  set series(Firstobs=10);
  r=_n_;
run;

proc sql; select max(r) into: maxi from series; quit;

%put &maxi;

data series2;
 retain adstock 0;
  set series;
  j=&maxi-_n_;
  if j= 20 then tvr=100;
  else if j= 65 then tvr=50;
  else if j=100 then tvr=75;
  else tvr=0;
  if j in (20,65,100) then adstock=&addecay*tvr; else adstock=&addecay*adstock;format adstock 8.2;
  sales_alt=sales;
  sales=sales+1.2*tvr + 2*adstock;
run;


PROC AUTOREG DATA = series2 outest=parameters;
	MODEL sales = adstock tvr / METHOD=ML MAXITER=50 NLAG=1 ;
run;

DATA _NULL_;
  set parameters;
  call symput ("intercept",intercept);
  call symput ("p_adstock",adstock);
  call symput ("p_tvr", tvr);
run;

%put &intercept;
%put &p_adstock;
%put &p_tvr;



goptions device=activex;
axis2 label=("Zeitraum" ) /*order=(0 to 2000 by 200)*/ ;
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

libname a "D:\DATEN\QUELLEN";

data a.adstock;
  set series2;
  retain error 0;

  adeffect=&p_adstock*adstock +&p_tvr*tvr;
  netsales=sales-adeffect;
  
  if r<=1101 then delete;
  drop i j sales_alt autocorr weekly random trend y1 y2 r;
  run;


title1 "Zeitreihendiagramm Werbewirkungsprognose";
proc gplot data=a.adstock;
plot  (sales adeffect netsales) *date/ overlay vaxis=axis2;
run;
quit;

ODS HTML close;
ods listing;
