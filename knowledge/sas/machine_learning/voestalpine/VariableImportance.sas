/* Ansatz Frau Mühlberger */
/* Normalerweise EXEL und Pivot, hier VA und CrossTab */

options cashost="dach-viya-smp.sas.com";
options CASPORT=5570;

cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" metrics=true);

libname sasdemo 	"/opt/data/demodata";

caslib _all_ assign;
caslib _all_ list;

proc casutil;
	load data=sasdemo.simulated_row7000_col1500 outcaslib="casdata" casout="simulated_row7000_col1500" promote;
    save casdata="simulated_row7000_col1500" incaslib="casdata" outcaslib="casdata" replace;
run; quit;

proc rank data=CASDATA.SIMULATED_ROW7000_COL1500 out=CASDATA.Rank groups=100;
	var y;
	ranks group;
run;

proc casutil;
	promote incaslib=casdata casdata="Rank" outcaslib=casdata casout="Rank";
run;


proc hpcorr data=CASDATA.SIMULATED_ROW7000_COL1500 nosimple rank outp=CASDATA.HPcorr_stats;
	var inf: noise: y;
run;

proc casutil;
	promote incaslib=casdata casdata="HPcorr_stats" outcaslib=casdata casout="HPcorr_stats";
run;

