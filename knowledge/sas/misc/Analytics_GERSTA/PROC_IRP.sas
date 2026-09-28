data work.skuinfo;
	input sku $ holdingCost fixedCost LTMean RTDMean RTDVar serviceLevel;
	datalines;
	A	0.35	90	1	125.1	2170.8	0.95
	B	0.05	50	2	140.3	1667.7	0.95
	C	0.12	50	3	116.0	3213.4	0.95
	D	0.10	75	1	291.8	5212.4	0.95
	E	0.45	75	2	134.5	1980.5	0.95
	;
	run;

proc print data=work.skuInfo;
run;

proc irp data=work.skuInfo out=work.policy;
      itemid sku;
      holdingcost holdingCost;
      leadtime / mean=LTmean;
      replenishment / fcost=fixedCost;
      reviewtimedemand / mean=RTDmean variance=RTDvar;
      service / level=serviceLevel;
run;

proc print data=work.policy;
run;


data work.skuinfo2;
	input sku $ holdingCost fixedCost LTMean LTVar RTDMean RTDVar serviceLevel;
	datalines;
	A	0.35	90	1	1.232    125.1	2170.8	0.99
	B	0.05	50	2	1.241    140.3	1667.7	0.99
	C	0.12	50	3	1.092    116.0	3213.4	0.99
	D	0.10	75	1	1.002    291.8	5212.4	0.99
	E	0.45	75	2	1.231    134.5	1980.5	0.99
	;
	run;

proc print data=work.skuInfo2;
run;

proc irp data=work.skuInfo2 out=work.policy2;
      itemid sku;
      holdingcost holdingCost;
      leadtime / mean=LTmean variance=LTVar;
      replenishment / fcost=fixedCost;
      reviewtimedemand / mean=RTDmean variance=RTDvar;
      service / level=serviceLevel;
run;

proc print data=work.policy2;
run;
