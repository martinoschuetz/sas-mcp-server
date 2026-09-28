cas mySession;
caslib _all_ assign;

proc casutil;
	load casdata="ALLE_ZYKLEN_ANONYM.sashdat" incaslib="public" outcaslib="public" casout="ALLE_ZYKLEN_ANONYM";
/*    save casdata="public" incaslib="public" outcaslib="ALLE_ZYKLEN_ANONYM" replace;*/
run; quit;


data public.Bearing(drop='Datum/Uhrzeit'n);
	attrib datetime format=DATETIME18. label="Messzeit Sekunden genau";
	attrib date format=date9. label="Tag der Messung";
	attrib hour label="Stunde der Messung";
	attrib minute label="Minute der Messung";
	attrib x1 label="Schwingung Gebläse-Lager AS (µm/s)";
	attrib x2 label="Schwingung Gebläse-Lager BS (µm/s)";
	attrib x3 label="Temperatur Gebläse-Lager AS (°C)";
	attrib x4 label="Temperatur Gebläse-Lager BS (°C)";
	attrib x5 label="Motorstrom Gebläse-Motor (A)";
	attrib x6 label="Drehzahl Gebläse (min)";
	attrib x7 label="Abgastemperatur Mittelwert (°C)";
	attrib x8 label="Staubmessung nach AG40  (mg/Nm³)";
	attrib x9 label="Unterdruck Mittelwert (mbar)";
	attrib x10 label="Volumenstrom (Nm³/h)";
	attrib x11 label="Durchfluss AV40 (Nm³/h)";
		
	set public.ALLE_ZYKLEN_ANONYM;
	datetime = input('Datum/Uhrzeit'n, DATETIME18.);
	datetime_short = input('Datum/Uhrzeit'n, DATETIME15.);
	date = datepart(datetime);
	hour = hour(datetime);
	minute = minute(datetime);	
run;

/* SVDD based on seconds */
ods noproctitle;
proc svdd data=public.Bearing(where=(herkunft=0)) standardize;
	input x:/ level=interval;
	kernel rbf / bw=mean2;
	solver stochs /;
	savestate rstore=public.Bearing_SVDD_Model_Seconds;
	id _all_;
run;

proc casutil;
	droptable incaslib="public" casdata="Bearing_Seconds_Scored";
run;
proc astore;
	score data=public.Bearing out=public.Bearing_Seconds_Scored 
		rstore=public.Bearing_SVDD_Model_Seconds;
run;

proc casutil;
	promote incaslib="public" casdata="Bearing_Seconds_Scored";
run;

/* Build Minute Table */
proc casutil;
	droptable incaslib="public" casdata="Bearing_Minute" quiet;
run;
proc fedsql sessref=mysession;
	create table public.Bearing_Minute as
	select zyklus, herkunft, date, hour, minute,
		avg(x1) as x1_avg, avg(x2) as x2_avg, avg(x3) as x3_avg, avg(x4) as x4_avg, avg(x5) as x5_avg,
		avg(x6) as x6_avg, avg(x7) as x7_avg, avg(x8) as x8_avg, avg(x9) as x9_avg, avg(x10) as x10_avg, avg(x11) as x11_avg
		from public.Bearing
		group by date, hour, minute, zyklus, herkunft;
quit;

data public.bearing_minute(drop=date hour minute);
	attrib datum format=DATETIME15. label="Messzeit Minuten genau";
	set public.bearing_minute;
	datum = DHMS( date, hour, minute, 0 );
run;

/* Build Hour Table */
proc casutil;
	droptable incaslib="public" casdata="Bearing_Hour" quiet;
run;
proc fedsql sessref=mysession;
	create table public.Bearing_Hour as
	select zyklus, herkunft, date, hour,
		avg(x1) as x1_avg, avg(x2) as x2_avg, avg(x3) as x3_avg, avg(x4) as x4_avg, avg(x5) as x5_avg,
		avg(x6) as x6_avg, avg(x7) as x7_avg, avg(x8) as x8_avg, avg(x9) as x9_avg, avg(x10) as x10_avg, avg(x11) as x11_avg
		from public.Bearing
		group by date, hour, zyklus, herkunft;
quit;

data public.Bearing_Hour(drop=date hour);
	attrib datum format=DATETIME12. label="Messzeit Stunden genau";
	set public.Bearing_Hour;
	datum = DHMS( date, hour, 0, 0 );
run;

/* SVDD based on minutes */
ods noproctitle;
proc svdd data=public.Bearing_Minute(where=(herkunft=0)) standardize;
	input x: / level=interval;
	kernel rbf / bw=mean2;
	solver stochs /;
	savestate rstore=public.Bearing_SVDD_Model_Minutes;
	id _all_;
run;

proc casutil;
	droptable incaslib="public" casdata="Bearing_Minute_Scored" quiet;
run;

proc astore;
	score data=public.Bearing_Minute out=public.Bearing_Minute_Scored 
		rstore=public.Bearing_SVDD_Model_Minutes;
run;

proc casutil;
	promote incaslib="public" casdata="Bearing_Minute_Scored";
run;

/* SVDD based on houres */
ods noproctitle;
proc svdd data=public.Bearing_Hour(where=(herkunft=0)) standardize;
	input x1: / level=interval;
	kernel rbf / bw=mean2;
	solver stochs /;
	savestate rstore=public.Bearing_SVDD_Model_Hour;
	id _all_;
run;

proc casutil;
	droptable incaslib="public" casdata="Bearing_Hour_Scored" quiet;
run;

proc astore;
	score data=public.Bearing_Hour out=public.Bearing_Hour_Scored 
		rstore=public.Bearing_SVDD_Model_Hour;
run;

proc casutil;
	promote incaslib="public" casdata="Bearing_Hour_Scored";
run;


proc casutil;
	promote incaslib="public" casdata="Bearing_Minute" outcaslib="public" casout="Bearing_Minute";
	promote incaslib="public" casdata="Bearing_Hour"   outcaslib="public" casout="Bearing_Hour";
run;
cas mySession terminate;