/* Sample code: Replicate frequency distribution */

data a ;
 do i=1 to 20;
 frequency=ranpoi(1234,4)+1;
 output;
 end;
run;

data b;
 set a;
 do j=1 to 20;

 if j<=frequency then do;
   value=1; output;
 end;

 end;
run;