libname a "/home/gersta";



%let nobs=1000000;
%let ncol=500;
%let tcol=100;


data a.test;
array numerisch(&ncol) x1-x&ncol;
array text(&tcol) $20. y1-y&tcol;

do i = 1 to &nobs;
   do j=1 to &ncol;
      numerisch(j)=ranuni(2344);
   end;
   do k =1 to &tcol;
      
      text(k) = put(ranuni(42354),20.);
   end;
   

output;
end;

drop i j k ;
run;

proc contents data=a.test;
run;