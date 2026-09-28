ODS listing close;
ODS HTML;

data demand;
	do t=1 to 40;
		price = (rannor(10) +5) * 10;
		income = 8000 * t ** (1/8);
		demand = 7200 - 1054 * price ** (2/3) + 
			7 * income + 100 * rannor(1);
		output;
	end;
run;

data goal;
	demand = 85000;
	income = 12686;
run;

proc model data=demand;
	demand = a1 - a2 * price ** (2/3) + a3 * income;
	fit demand / outest=demest;
	solve price  / estdata=demest data=goal solveprint;
run;

quit;

ODS HTML close;
ODS Listing;