libname smp "C:\Arbeit\Projekte\sas.for.dummies\data";

ods html body="test.html" path="c:\temp" style=journal;
ods graphics on / width=900px;
title "Control Chart of CO2 by Date (Regelkarte)";

/* scatterplot with smoothing and a cl of 95% */
proc loess data=smp.air;
	ods output OutputStatistics = airfit;
	model co = datetime / smooth=.3 direct alpha=.05 residual all;
run;

proc shewhart data=smp.air;
	uchart co * datetime / 
		odstitle=""
		subgroupn=1 
		testnmethod=standardize  
		nohlabel
		nolegend;
run;

/* mit variablen Limits */
data air;
	set smp.air;
	_phase_="1";
	if datetime > "17nov1989:00:00:00"dt then _phase_="2";
run;

proc shewhart data=air; by _phase_;
	uchart co * datetime / subgroupn = 1 nochart
	outlimits = vislimit (rename=(_phase_=_index_));
run;

proc shewhart data=air limits=vislimit;
	uchart co * datetime / 
		odstitle=""
		subgroupn=1 
		testnmethod=standardize  
		readindex = all
		readphase = all
		nohlabel
		nolegend;
run;

ods graphics off;

ods html close;
