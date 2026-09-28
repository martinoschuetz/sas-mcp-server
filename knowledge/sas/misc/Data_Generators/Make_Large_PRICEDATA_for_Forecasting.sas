
/* Create artificial series*/

%let series=10;

%macro stack1;
%do i=1 %to &series;
data tmp&i;
 set sashelp.pricedata;
 length productline2 $30.;
 length productname2 $30.;
 productline2='Line'||strip(substr(productline,5,2))||'_'||strip(&i);
 productname2='Product'||strip(substr(productname,8,2))||'_'||strip(&i);
 sale=int(sale+rannor(1234)*10);
 keep date sale price discount cost region productline2 productname2 ;
run;
%end;
%mend;

%stack1;

data work.pricedata_large;
 set tmp1-tmp&series;
 
run;