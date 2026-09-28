libname yyy "/home/gersta/sasdata";
libname xxx "/hadoop/exchange/dump/sasdata";
%let nreply=30;
%let dsn=yyy.modeltrain_v5;

data xxx.tmp0;
 set yyy.modeltrain_v5m;
  copy =0;
 run;

data xxx.tmp1;
	set &dsn;
	copy=1;
run;

%Macro replicate;
	%do i=2 %to &nreply;

		data xxx.tmp&i;
			set &dsn;
			copy=&i;
		run;

		proc append base=xxx.tmp1 data=xxx.tmp&i;
		run;

		proc delete data=xxx.tmp&i;
		run;

	%end;
%mend;

%replicate;

data yyy.modeltrain_v5xxl(compress=yes);
	set xxx.tmp0 xxx.tmp1;

array inputs {6} pr0_val pr1_val pr2_val flow0_val flow1_val flow2_val;

do i = 1 to 6;
    inputs(i)=inputs(i)+rannor(1234)/3;
end; 

drop i;

run;
