options xsync;
data _null_;
x "CD \";
x "CD SASDATA";
x "DEL -fq transactions.csv";
run;
data _null_;
x "C:\SASDATA\Demo_excel2.vbs";
run;
libname a "C:\SASDATA";
data a.test;
infile "C:\SASDATA\Transactions.csv" dsd delimiter="," firstobs=2;
input obs
cust_id
gender $
age
cust_duration
trx_amount_avg_lm
trx_amount_sd_lm
trx_count_lm
trx_velocity_lm;
label obs="Observation No."
cust_id="Customer ID"
gender ="Customer Gender"
age="Customer Age"
cust_duration="Customer Tenancy"
trx_amount_avg_lm="Avg. Trx Amount Last Month"
trx_amount_sd_lm="Stddev of Trx Amount Last Month"
trx_count_lm="No. of Transactions Last Month"
trx_velocity_lm="Transaction Velocity Last Month";
format trx_amount_avg_lm trx_amount_sd_lm trx_count_lm trx_velocity_lm 8.2;
run;
Title "Descriptive Summary of Last Month Transaction Amount";
proc means data=a.test mean std n median q1 q3;
var trx_amount_avg_lm;
run;
%em_register(key=results, type=DATA);
data &em_user_results;
set a.test;
run;
%em_report(Autodisplay=Y, key=results, viewtype=Data,description=Sample of CSV File);
