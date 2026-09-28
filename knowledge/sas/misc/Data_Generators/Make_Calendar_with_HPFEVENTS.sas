/* Create German Holiday Calendar */
%let range=14000;

data calendar;
	do i=1 to &range;
		date=today()+365*30-&range-1+i;
		flag=1;
		weekday=weekday(date);
		output;
	end;

	format date date9.;
	drop i;
run;

proc sql noprint;
	select max(date) format date9. into:maxdate from calendar;

proc sql noprint;
	select min(date) format date9. into:mindate from calendar;

%put &=maxdate;
%put &=mindate;

proc hpfevents data=calendar;
	var weekday;
	id date interval=day start="01JAN2015"D end="31DEC2018"D;
	eventdef weihnachten1  		= christmas / type=point;
	eventdef weihnachten2  		= christmas / type=point shift=1;
	eventdef heiligabend   		= christmas / type=point shift= - 1;
	eventdef ostersonntag  		= easter    / type=point;
	eventdef ostermontag   		= easter    / type=point shift=1;
	eventdef karfreitag    		= easter    / type=point shift=-2;
	eventdef pfingstsonntag 	= easter    / type=point shift=49;
	eventdef pfingstmontag 		= easter    / type=point shift=50;
	eventdef christi_himmelfahrt= easter 	/ type=point shift=39;
	eventdef fronleichnahm		= easter 	/ type=point shift=60;
	eventdef rosenmontag        = easter     / type=point shift=-27;
	eventdef neujahr            = '01JAN2015'D / type=point period=YEAR;
	eventdef sylvester          = '31DEC2015'D / type=point period=YEAR;
	eventdef tag_der_arbeit     = '01MAY2015'D / type=point period=YEAR;
	eventdef deutsche_einheit    = '03OCT2015'D / type=point period=YEAR;
	eventdef allerheiligen      = '01NOV2015'D / type=point period=YEAR;
	eventdef reformationstag    = '31OCT2015'D / type=point period=YEAR;
	eventdef mariae_himmelfahrt  = '15AUG2015'D / type=point period=YEAR;
	eventdef friedensfest       = '08AUG2015'D / type=point period=YEAR;
	eventdef heilige_drei_koenige= '06JAN2015'D / type=point period=YEAR;
	eventdef valentinstag       = '14FEB2015'D / type=point period=YEAR;
	eventcomb event_flag = 
		weihnachten1
		weihnachten2
		heiligabend
		ostersonntag
		ostermontag
		karfreitag
		pfingstsonntag
		pfingstmontag
		christi_himmelfahrt
		fronleichnahm
		rosenmontag
		neujahr
		sylvester
		tag_der_arbeit
		deutsche_einheit
		allerheiligen
		reformationstag
		mariae_himmelfahrt
		friedensfest
		heilige_drei_koenige
		valentinstag
	;
	eventdummy out= events;
run;

data events2;
	set events;
	length wochentag $30.;
	length eventname $50.;

	if weihnachten1=1 then
		eventname='Weihnachten 1. Feiertag';

	if weihnachten2=1 then
		eventname='Weihnachten 2. Feiertag';

	if heiligabend=1 then
		eventname='Heiligabend';

	if ostersonntag=1 then
		eventname='Ostersonntag';

	if ostermontag=1 then
		eventname='Ostermontag';

	if karfreitag=1 then
		eventname='Karfreitag';

	if pfingstsonntag=1 then
		eventname='Pfingstsonntag';

	if pfingstmontag=1 then
		eventname='Pfingstmontag';

	if christi_himmelfahrt=1 then
		eventname='Christi Himmelfahrt';

	if fronleichnahm=1 then
		eventname='Fronleichnahm';

	if rosenmontag=1 then
		eventname='Karneval(Rosenmontag)';

	if neujahr=1 then
		eventname='Neujahr';

	if sylvester=1 then
		eventname='Sylvester';

	if tag_der_arbeit=1 then
		eventname='Tag der Arbeit';

	if deutsche_einheit=1 then
		eventname='Tag der Deutschen Einheit';

	if allerheiligen=1 then
		eventname='Allerheiligen';

	if reformationstag=1 then
		eventname='Reformationstag';

	if mariae_himmelfahrt=1 then
		eventname='Mariä Himmelfahrt';

	if friedensfest=1 then
		eventname ='Augsburger Friedensfest';

	if heilige_drei_koenige=1 then
		eventname ='Heilige Drei Könige';

	if valentinstag=1 then
		eventname ='Valentinstag';

	if weekday=1 then
		Wochentag='(1) Sonntag';

	if weekday=2 then
		Wochentag='(2) Montag';

	if weekday=3 then
		Wochentag='(3) Dienstag';

	if weekday=4 then
		Wochentag='(4) Mittwoch';

	if weekday=5 then
		Wochentag='(5) Donnerstag';

	if weekday=6 then
		Wochentag='(6) Freitag';

	if weekday=7 then
		Wochentag='(7) Samstag';
	keep date event_flag wochentag eventname;
run;

proc sort data=events2 out=events3;
	by descending date;
run;

data events4;
	set events3;
	weekn=week(date);
	retain cntxms;

	if month(date)=12 and day(date)=24 then
		cntxms=0;

	if dif(weekn) ne 0 then
		cntxms=cntxms+1;

	if weekday(date)=7 and cntxms=1 then
		advent4=1;
	else advent4=0;

	if weekday(date)=7 and cntxms=2 then
		advent3=1;
	else advent3=0;

	if weekday(date)=7 and cntxms=3 then
		advent2=1;
	else advent2=0;

	if weekday(date)=7 and cntxms=4 then
		advent1=1;
	else advent1=0;

	if advent1=1 then
		eventname='1. Advent';

	if advent2=1 then
		eventname='2. Advent';

	if advent3=1 then
		eventname='3. Advent';

	if advent4=1 then
		eventname='4. Advent';

	if sum(advent1, advent2, advent3, advent4)>0 then
		event_flag=1;
	by descending date;
	drop weekn cntxms advent1 advent2 advent3 advent4;
run;

proc sort data=events4 out=events_daily;
	by date;
run;

proc timeseries data=events_daily out=events_weekly;
	id date interval=WEEK.2;
	var  event_flag / ACCUMULATE=max;
run;
