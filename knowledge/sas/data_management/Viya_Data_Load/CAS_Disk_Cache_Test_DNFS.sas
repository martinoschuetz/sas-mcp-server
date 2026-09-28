cas mysession;

/* run the shell script */
proc casutil;
	load casdata="big_prdsale.sashdat" incaslib="dm_dnfs" outcaslib="dm_dnfs" 
		casout="&sysuserid._myprdsale" replace;
	list tables incaslib="dm_dnfs";
run;
quit;

/* run the shell script */
proc casutil;
	droptable casdata="&sysuserid._myprdsale" incaslib="dm_dnfs" quiet;
	list tables incaslib="dm_dnfs";
run;
quit;

/* run the shell script */
proc casutil;
	load casdata="big_prdsale.sashdat" incaslib="dm_dnfs" outcaslib="dm_dnfs" 
		casout="&sysuserid._myprdsale" replace;
	list tables incaslib="dm_dnfs";
run;

quit;

/* run the shell script */
proc casutil;
	droptable casdata="&sysuserid._myprdsale" incaslib="dm_dnfs" quiet;
	list tables incaslib="dm_dnfs";
run;

quit;

/* run the shell script */
cas mysession terminate;