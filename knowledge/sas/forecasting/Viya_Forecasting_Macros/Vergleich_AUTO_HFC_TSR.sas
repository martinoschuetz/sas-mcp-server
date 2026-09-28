data auto;
	set data_out.seg_long_a_auto;
	if date ge '01APR2019'd and date le '01JUN2019'd;
run;

data HFC;
	set data_out.seg_long_a_HFC;
	if date ge '01APR2019'd and date le '01JUN2019'd;
run;

data TSR;
	set data_out.seg_long_a_TSR;
	if date ge '01APR2019'd and date le '01JUN2019'd;
run;

data only_TSR;
	merge auto (in=in1) HFC (in=in2) TSR (in=in3);
	by fc_var date;
	if in1=0 or in2=0;
run;


proc summary data=auto nway;
	var error;
	outout out=auto_sum sum=error_AUTO;
run;

proc summary data=TSR nway;
	var error;
	outout out=TSR_sum sum=error_TSR;
run;


proc summary data=HFC nway;
	var error;
	outout out=HFC_sum sum=error_HFC;
run;

data summen;
	merge  auto_sum  HFC_sum TSR_sum;
run;





proc sort data=only_TSR nodupkey;
	by fc_var;
run;	


proc sort data=data_in.Seg_long_a ;
	by fc_var date;
run;	



data auto_fail;
	merge  data_in.Seg_long_a only_TSR (in=in2 keep=fc_var) ;
	by fc_var;
	if in2;
run;