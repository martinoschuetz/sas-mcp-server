cas mySession;

data myprdsale;
	set sashelp.prdsale;

	do i=1 to 1000;
		output;
	end;
run;

proc casutil;
	load data=myprdsale outcaslib="casuser" casout="&sysuserid._myprdsale" replace;
	list tables incaslib="casuser";
run;

quit;

proc casutil;
	promote casdata="&sysuserid._myprdsale" incaslib="casuser" outcaslib="casuser" 
		casout="&sysuserid._myprdsale";
	list tables incaslib="casuser";
run;

quit;

proc casutil;
	droptable casdata="&sysuserid._myprdsale" incaslib="casuser" quiet;
	list tables incaslib="casuser";
run;
quit;

cas mysession terminate ;

