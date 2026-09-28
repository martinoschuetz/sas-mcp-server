/* Create German Holiday Calendar */
%let range=14000;

data calendar;
	do i=1 to &range;
		DATE=today()+365*2-&range-1+i;
		WEEKDAY=weekday(date);
		YEAR=year(date);
		WEEK=week(date,'v');
		MONTH=month(date);
		DAY_OF_MONTH=day(date);
		output;
	end;

	format date date9.;
	drop i;
run;

data calendar;
	set calendar;

	if date=holiday('easter', year(date)) then
		OSTERSONNTAG=1;
	else OSTERSONNTAG=0;

	if date=holiday('easter', year(date))+1 then
		OSTERMONTAG=1;
	else OSTERMONTAG=0;

	if date=holiday('easter', year(date))-2 then
		KARFREITAG=1;
	else KARFREITAG=0;

	if date=holiday('easter', year(date))+49 then
		PFINGSTSONNTAG=1;
	else PFINGSTSONNTAG=0;

	if date=holiday('easter', year(date))+50 then
		PFINGSTMONTAG=1;
	else PFINGSTMONTAG=0;

	if date=holiday('easter', year(date))+39 then
		CHRISTI_HIMMELFAHRT=1;
	else CHRISTI_HIMMELFAHRT=0;

	if date=holiday('easter', year(date))+60 then
		FRONLEICHNAHM=1;
	else FRONLEICHNAHM=0;

	if date=holiday('easter', year(date))-48 then
		ROSENMONTAG=1;
	else ROSENMONTAG=0;

	if date=holiday('easter', year(date))-47 then
		FASCHINGSDIENSTAG=1;
	else FASCHINGSDIENSTAG=0;

	if month(date)=1 and day(date)=1 then
		NEUJAHR=1;
	else NEUJAHR=0;

	if month(date)=12 and day(date)=31 then
		SYLVESTER=1;
	else SYLVESTER=0;

	if month(date)=12 and day(date)=24 then
		HEILIGABEND=1;
	else HEILIGABEND=0;

	if month(date)=12 and day(date)=25 then
		WEIHNACHTSFEIERTAG_1=1;
	else WEIHNACHTSFEIERTAG_1=0;

	if month(date)=12 and day(date)=26 then
		WEIHNACHTSFEIERTAG_2=1;
	else WEIHNACHTSFEIERTAG_2=0;

	if month(date)=5 and day(date)=1 then
		TAG_DER_ARBEIT=1;
	else TAG_DER_ARBEIT=0;

	if month(date)=10 and day(date)=3 then
		DEUTSCHE_EINHEIT=1;
	else DEUTSCHE_EINHEIT=0;

	if month(date)=11 and day(date)=1 then
		ALLERHEILIGEN=1;
	else ALLERHEILIGEN=0;

	if month(date)=1 and day(date)=6 then
		HLG_DREI_KOENIGE=1;
	else HLG_DREI_KOENIGE=0;

	if month(date)=8 and day(date)=15 then
		MARIAE_HIMMELFAHRT=1;
	else MARIAE_HIMMELFAHRT=0;

	if month(date)=10 and day(date)=31 then
		REFORMATIONSTAG=1;
	else REFORMATIONSTAG=0;

	if month(date)=2 and day(date)=14 then
		VALENTINSTAG=1;
	else VALENTINSTAG=0;

	if month(date)=12 and day(date)=6 then
		NIKOLAUS=1;
	else NIKOLAUS=0;

	if month(date)=10 and day(date)=31 then
		HALLOWEEN=1;
	else HALLOWEEN=0;

	if weekday=4 and -7<=(date-mdy(11,23,year))<=-1 then
		BUSS_UND_BETTAG=1;
	else BUSS_UND_BETTAG=0;

	if date=nwkdom(2, 1, 5, year) then
		MUTTERTAG=1;
	else MUTTERTAG=0;
	length WOCHENTAG $20.0;

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
	LENGTH FEIERTAG_BUND $30.;

	if WEIHNACHTSFEIERTAG_1=1 then
		feiertag_bund='Weihnachten 1. Feiertag';

	if WEIHNACHTSFEIERTAG_2=1 then
		feiertag_bund='Weihnachten 2. Feiertag';

	if heiligabend=1 then
		feiertag_bund='Heiligabend';

	if ostersonntag=1 then
		feiertag_bund='Ostersonntag';

	if ostermontag=1 then
		feiertag_bund='Ostermontag';

	if karfreitag=1 then
		feiertag_bund='Karfreitag';

	if pfingstsonntag=1 then
		feiertag_bund='Pfingstsonntag';

	if pfingstmontag=1 then
		feiertag_bund='Pfingstmontag';

	if christi_himmelfahrt=1 then
		feiertag_bund='Christi Himmelfahrt';

	if neujahr=1 then
		feiertag_bund='Neujahr';

	if sylvester=1 then
		feiertag_bund='Sylvester';

	if tag_der_arbeit=1 then
		feiertag_bund='Tag der Arbeit';

	if deutsche_einheit=1 then
		feiertag_bund='Tag der Deutschen Einheit';
	LENGTH FEIERTAG_REGIONAL $30.;

	if fronleichnahm=1 then
		FEIERTAG_REGIONAL='Fronleichnahm';

	if allerheiligen=1 then
		FEIERTAG_REGIONAL='Allerheiligen';

	if reformationstag=1 then
		FEIERTAG_REGIONAL='Reformationstag';

	if mariae_himmelfahrt=1 then
		FEIERTAG_REGIONAL='Mariä Himmelfahrt';

	if hlg_drei_koenige=1 then
		FEIERTAG_REGIONAL='Heilige Drei Könige';

	if buss_und_bettag=1 then
		FEIERTAG_REGIONAL='Buss- und Bettag';
	LENGTH SONSTIGER_EVENT $30.;

	if valentinstag=1 then
		SONSTIGER_EVENT='Valentinstag';

	if muttertag=1 then
		SONSTIGER_EVENT='Muttertag';

	if nikolaus=1 then
		SONSTIGER_EVENT='Nikolaus';

	if HALLOWEEN=1 then
		SONSTIGER_EVENT='Halloween';

	if rosenmontag=1 then
		SONSTIGER_EVENT='Karneval (Rosenmontag)';

	if faschingsdienstag=1 then
		SONSTIGER_EVENT='Karneval (Faschingsdienstag)';
	lagweekday=lag(weekday);
	x=FEIERTAG_BUND;

	if FEIERTAG_REGIONAL in ("Allerheiligen", "Heilige Drei Könige", "Fronleichnahm") then
		x=FEIERTAG_REGIONAL;
	xlag=lag(x);
	LENGTH BRUECKENTAG $30.;

	if weekday=6 and lengthn(xlag)>0 and lengthn(x)=0 then
		BRUECKENTAG='Brückentag';
	keep date year week month weekday day_of_month wochentag feiertag_bund feiertag_regional sonstiger_event brueckentag;
run;

proc sort data=calendar out=calendar2;
	by descending date;
run;

data calendar3;
	set calendar2;
	retain cntxms;

	if month=12 and day(date)=24 then
		cntxms=0;

	if dif(week) ne 0 then
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

	if lengthn(eventname)>0 then
		SONSTIGER_EVENT=eventname;
	by descending date;
	drop cntxms advent1 advent2 advent3 advent4 eventname;
run;

proc sort data=calendar3 out=calendar4;
	by date;
run;

data calendar5;
	set calendar4;
	x=FEIERTAG_BUND;

	if FEIERTAG_REGIONAL in ("Allerheiligen", "Heilige Drei Könige", "Fronleichnahm") then
		x=FEIERTAG_REGIONAL;

	if weekday=3 and lengthn(x)>0 then
		flag1=1;

	if flag1=1;
	BRUECKENTAG='Brückentag';
	date=date-1;
	keep date brueckentag;
run;

data calendar6;
	merge calendar4 calendar5;
	by date;
	EVENT_ALLE=catx(" ",feiertag_bund, feiertag_regional, sonstiger_event, brueckentag);
	label date="Kalenderdatum"
		week="Kalenderwoche"
		day_of_month="Tag des Monats"
		month="Monat"
		year="Jahr"
		wochentag="Wochentag"
		feiertag_bund="Feiertag (bundeseinheitlich)"
		feiertag_regional="Feiertag (regional)"
		brueckentag="Brückentag"
		sonstiger_event="Sonstiger Event"
		event_alle="Alle Events";
	drop weekday;
	rename date=KALENDERDATUM;
	rename day_of_month=MONATSTAG;
	rename month=MONAT;
	rename week=KALENDERWOCHE;
	rename year=JAHR;
run;

data calendar_final;
	set calendar6;
run;

proc export data=work.calendar_final(rename=(Kalenderdatum=datum)) outfile="C:\Public\Kalender.csv" replace;
	delimiter=';';
run;