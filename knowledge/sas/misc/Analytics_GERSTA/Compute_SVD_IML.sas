/* read in data */


%let nrows=1000000;
%let ncols=100;

data tmp;
   array vec1 {&ncols} x1-x&ncols;
   do i =1 to &nrows;
     do j=1 to &ncols;

       if ranuni(1212)>0.8 then vec1(j)=ranpoi(1232,3);
	   else vec1(j)=0;
	 end;
      
   output;

   end;

   drop i j;
 
 run;


 proc iml;

/* Read in data matrices */
  use tmp;
  read all var _num_ into x;
 call svd(u,q,v,x); 

 create u from u; append from u;
 
 
 create q from q; append from q;

 create v from v; append from v;

  quit;

  data q;
   set q;
   svd=_n_;
run;
 ods graphics;
proc sgplot data=q;
  series x=svd y=col1;
 run;

 ods graphics off;