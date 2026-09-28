/* This is an example for spectral analysis to estimate coefficients for Fourier transformation 

For details, see http://support.sas.com/documentation/cdl/en/etsug/63348/HTML/default/viewer.htm#spectra_toc.htm */


data test;
 set sashelp.air;
 air2=dif(log(air));
run;

proc spectra data=test out=b(where=(period<=120)) coeff p s ;
 var air2;
weights parzen 0.5 0;
run;


libname tsa "C:\temp";

data tsa.temp (drop=i);
   do i=1 to 365;
     date=(today()-365)+i;
   output;
   end;
format date date9.;
run;
%let frequenz=(2*3.14159265358979)/(365/2);

data tsa.data;
 set tsa.temp;
 series=0.25*cos(&frequenz*(_N_-89))+0.25*sin(&frequenz*(_N_-89))+100+rannor(1)/1000;
run;


/*
axis2 label=(a=-90 r=90 "Time Series Value" );
symbol1 color=blue
        interpol=join
        value=star
        height=1;
*/
proc gplot data=tsa.nextdata;
plot series * date = 1;
run;