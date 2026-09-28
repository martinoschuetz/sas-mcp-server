options set=SASMYL MYWIN417; 

libname MYSQLDAT MYSQL user=sasdemo password=<REDACTED> database=analyticmart
server=gersta port=3306;

data temp;
 set mysqldat.snacks;
run;