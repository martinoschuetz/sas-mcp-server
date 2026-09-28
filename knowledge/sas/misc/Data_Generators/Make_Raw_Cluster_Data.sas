


%let c1=4000;
%let c2=8000;
%let c3=7000;
%let c4=1000;

data pseudocluster;

  do i=1 to &c1;
     c=1;
     f01=50+rannor(123)*20;
	 f02=50+rannor(123)*20;
	 f03=50+rannor(123)*20;
	 f04=50+rannor(123)*20;
	 f05=0+rannor(123)*20;
	 f06=0+rannor(123)*20;
	 f07=0+rannor(123)*20;
	 f08=0+rannor(123)*20;
	 f09=0+rannor(123)*20;
	 f10=0+rannor(123)*20;
	 f11=0+rannor(123)*20;
	 f12=0+rannor(123)*20;
	 f13=0+rannor(123)*20;
	 f14=0+rannor(123)*20;
	 f15=0+rannor(123)*20;
	 f16=0+rannor(123)*20;
	 f17=0+rannor(123)*20;
	 f18=0+rannor(123)*20;
	 f19=0+rannor(123)*20;
	 f20=0+rannor(123)*20;
  output;
  end;
  do i=1 to &c2;
     c=2;
     f01=0+rannor(123)*20;
	 f02=0+rannor(123)*20;
	 f03=0+rannor(123)*20;
	 f04=0+rannor(123)*20;
	 f05=50+rannor(123)*20;
	 f06=50+rannor(123)*20;
	 f07=50+rannor(123)*20;
	 f08=50+rannor(123)*20;
	 f09=50+rannor(123)*20;
	 f10=50+rannor(123)*20;
	 f11=0+rannor(123)*20;
	 f12=0+rannor(123)*20;
	 f13=0+rannor(123)*20;
	 f14=0+rannor(123)*20;
	 f15=0+rannor(123)*20;
	 f16=0+rannor(123)*20;
	 f17=0+rannor(123)*20;
	 f18=0+rannor(123)*20;
	 f19=0+rannor(123)*20;
	 f20=0+rannor(123)*20;

output;
  end;
  do i=1 to &c3;
     c=3;
     f01=0+rannor(123)*20;
	 f02=0+rannor(123)*20;
	 f03=0+rannor(123)*20;
	 f04=0+rannor(123)*20;
	 f05=0+rannor(123)*20;
	 f06=0+rannor(123)*20;
	 f07=0+rannor(123)*20;
	 f08=0+rannor(123)*20;
	 f09=0+rannor(123)*20;
	 f10=0+rannor(123)*20;
	 f11=50+rannor(123)*20;
	 f12=50+rannor(123)*20;
	 f13=50+rannor(123)*20;
	 f14=50+rannor(123)*20;
	 f15=50+rannor(123)*20;
	 f16=0+rannor(123)*20;
	 f17=0+rannor(123)*20;
	 f18=0+rannor(123)*20;
	 f19=0+rannor(123)*20;
	 f20=0+rannor(123)*20;
  output;
  end;

  do i=1 to &c4;
     c=4;
     f01=0+rannor(123)*20;
	 f02=0+rannor(123)*20;
	 f03=0+rannor(123)*20;
	 f04=0+rannor(123)*20;
	 f05=0+rannor(123)*20;
	 f06=0+rannor(123)*20;
	 f07=0+rannor(123)*20;
	 f08=0+rannor(123)*20;
	 f09=0+rannor(123)*20;
	 f10=0+rannor(123)*20;
	 f11=0+rannor(123)*20;
	 f12=0+rannor(123)*20;
	 f13=0+rannor(123)*20;
	 f14=0+rannor(123)*20;
	 f15=0+rannor(123)*20;
	 f16=50+rannor(123)*20;
	 f17=50+rannor(123)*20;
	 f18=50+rannor(123)*20;
	 f19=50+rannor(123)*20;
	 f20=50+rannor(123)*20;
  output;
  end;
  drop i;

run;

data pseudocluster; 
object_id =_N_;
set pseudocluster;
run;


proc stdize data=pseudocluster out=clusterinput method=std out=clusterinput;
var f01--f20;
run;

proc means data=clusterinput mean std n;
 var f01--f20;
run;

 
proc means data=clusterinput mean std n;
 var f01--f20;
 by c;
 run;

 libname mcc "C:\TEMP";
 
 data mcc.cluster_fake;
  set clusterinput;
  run;

  proc export  data=mcc.cluster_fake outfile="C:\TEMP\rawdata.csv" replace dbms=CSV replace;
  run;