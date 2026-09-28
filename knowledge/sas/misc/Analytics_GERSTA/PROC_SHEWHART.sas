options pagesize=500;

libname qctest "C:\temp";

data qctest.qc_data (drop=i);
   center =100;
   do i=1 to 100;
   error=ranuni(1);
   date=(today()-100)+i;
   series=100+4*error-2;
   output;
   end;
   
run;

proc print data=qctest.qc_data;
format date date9.;
run;

symbol1 color=blue
        interpol=join
        value=diamond
        height=1;
symbol2 color=red
        value=circle
		interpol=join
        height=1;


proc gplot data=qctest.qc_data;
  plot series*date center*date /overlay vaxis=80 to 120 by 10 haxis=16006 to 16105 by 10;
  format date date7.;
run;

proc shewhart data=qctest.qc_data;
      irchart series*date;
   run;
