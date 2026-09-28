ODS _ALL_ CLOSE;
ODS tagsets.excelxp
	file="C:\Projekte\Demo\ESTG\DATA\XLS\Terms3.xls"
	style=statistical
	options(
	skip_space='3,2,0,0,1'
	sheet_interval='1' /* 'none' */
	suppress_bylines='no'
	);

proc sort data=tmp.key2 out=key2_sorted;
	by role;
run;

proc print noobs
	data=key2_sorted; /* (where=(role EQ 'CURRENCY')); */
	by role;
	format p_: f10.3;
run;

ods tagsets.excelxp close;