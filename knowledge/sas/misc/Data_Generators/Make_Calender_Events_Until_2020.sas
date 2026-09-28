


/*Vorbereitung des Eventkalenders: erzeuge zunächst Tageskalender als SAS-Tabelle 
mit Kalenderdaten von 2000-2020 */

/* Feiertage gemäß http://kalender-365.de */

data tageskalender (Label='Tageskalendar von 2000 - 2020' drop=i);
do i=1 to 7671;
	tag='31DEC1999'd+i;
	format tag DATE9.;
	output;
end;
run;


/* Erstelle Event-Spalte und füge Infos über feste und bewegliche Feiertage sowie 
   Brückentage und sonstige Tage mit Retail-Relevanz ein */

data tageskalender;
  set tageskalender;
  datum=tag;
  length event $ 40;
  if month(tag)=1 and day(tag)=1 then event='Neujahr';
  else if month(tag)=1 and day(tag)=6 then event='Heilige Drei Könige';
  else if tag in ('06MAR2000'D,
                  '26FEB2001'D,
                  '11FEB2002'D,
				  '03MAR2003'D,
				  '23FEB2004'D,
				  '07FEB2005'D,
				  '27FEB2006'D,
				  '19FEB2007'D,
				  '04FEB2008'D,
				  '23FEB2009'D,
				  '15FEB2010'D,
				  '07MAR2011'D,
				  '20FEB2012'D,
				  '11FEB2013'D,
				  '03MAR2014'D,
				  '16FEB2015'D,
				  '08FEB2016'D,
				  '27FEB2017'D,
				  '12FEB2018'D,
				  '04MAR2019'D,
				  '24FEB2020'D) 
  then event='Rosenmontag';
  else if tag in ('21APR2000'D,
                  '13APR2001'D,
                  '29MAR2002'D,
                  '18APR2003'D,
                  '09APR2004'D,
                  '25MAR2005'D,
                  '14APR2006'D,
                  '06APR2007'D,
                  '21MAR2008'D,
                  '10APR2009'D,
				  '02APR2010'D,
                  '22APR2011'D,
				  '06APR2012'D,
				  '29MAR2013'D,
				  '18APR2014'D,
				  '03APR2015'D,
				  '25MAR2016'D,
				  '14APR2017'D,
				  '30MAR2018'D,
				  '19APR2019'D,
				  '10APR2020'D) 
  then event='Karfreitag';
  else if tag in ('23APR2000'D,
                  '15APR2001'D,
				  '31MAR2002'd,
				  '20APR2003'D,
				  '11APR2004'D,
				  '27MAR2005'D,
				  '16APR2006'D,
				  '08APR2007'D,
				  '23MAR2008'D,
				  '12APR2009'D,
				  '04APR2010'D,
				  '24APR2011'D,
				  '08APR2012'D,
				  '31MAR2013'D,
				  '20APR2014'D,
				  '05APR2015'D,
				  '27MAR2016'D,
				  '16APR2017'D,
				  '01APR2018'D,
				  '21APR2019'D,
				  '12APR2020'D)
  then event='Ostersonntag';
  else if tag in ('24APR2000'D,
                  '16APR2001'D,
				  '01APR2002'D,
				  '21APR2003'D,
				  '12APR2004'D,
				  '28MAR2005'D,
				  '17APR2006'D,
				  '09APR2007'D,
				  '24MAR2008'D,
				  '13APR2009'D,
				  '05APR2010'D,
                  '25APR2011'D,
				  '09APR2012'D,
				  '01APR2013'D,
				  '21APR2014'D,
				  '06APR2015'D,
				  '28MAR2018'D,
				  '17APR2017'D,
				  '02APR2018'D,
				  '22APR2019'D,
				  '13APR2020'D)

then event='Ostermontag';
else if month(tag)=5 and day(tag)=1 then event='Maifeiertag';
  else if tag in ('01JUN2000'D,
                  '24MAY2001'D,
                  '09MAY2002'D,
                  '29MAY2003'D, 
                  '20MAY2004'D,
                  '05MAY2005'D,
                  '25MAY2006'D,
                  '17MAY2007'D,
                  '01MAY2008'D,
				  '21MAY2009'D,
				  '13MAY2010'D,
                  '02JUN2011'D,
				  '17MAY2012'D,
				  '09MAY2013'D,
				  '29MAY2014'D,
				  '14MAY2015'D,
				  '05MAY2016'D,
				  '25MAY2017'D,
				  '10MAY2018'D,
				  '30MAY2019'D,
				  '21MAY2020'D) 
  then event='Christi Himmelfahrt';
  else if tag in ('11JUN2000'D, 
                  '02JUN2001'D,
                  '19MAY2002'D,
                  '08JUN2003'D,
                  '30MAY2004'D, 
                  '15MAY2005'D,
                  '04JUN2006'D,
				  '27MAY2007'D,
				  '11MAY2008'D,
				  '31MAY2009'D,
				  '23MAY2010'D,
                  '12JUN2011'D,
				  '27MAY2012'D,
				  '19MAY2013'D,
				  '08JUN2014'D,
				  '24MAY2015'D,
				  '15MAY2016'D,
				  '04JUN2017'D,
				  '20MAY2018'D,
				  '09JUN2019'D,
				  '31MAY2020'D)
  then event='Pfingstsonntag';
  else if tag in ('12JUN2000'D, 
                  '04JUN2001'D,
                  '20MAY2002'D,
                  '09JUN2003'D,
                  '31MAY2004'D, 
                  '16MAY2005'D,
                  '05JUN2006'D,
				  '28MAY2007'D,
				  '12MAY2008'D,
				  '01JUN2009'D,
				  '24MAY2010'D,
                  '13JUN2011'D,
				  '28MAY2012'D,
				  '20MAY2013'D,
				  '09JUN2014'D,
				  '25MAY2015'D,
				  '16MAY2016'D,
				  '05JUN2017'D,
				  '21MAY2018'D,
				  '10JUN2019'D,
				  '01JUN2020'D)
  then event='Pfingstmontag';
  else if tag in ('22JUN2000'D,
                  '14JUN2001'D,
                  '30MAY2002'D,
                  '19JUN2003'D,
                  '10JUN2004'D,
                  '26MAY2005'D,
                  '15JUN2006'D,
                  '07JUN2007'D,
				  '22MAY2008'D,
				  '11JUN2009'D,
				  '03JUN2010'D,
				  '23JUN2011'D,
				  '07JUN2012'D,
				  '30MAY2013'D,
				  '19JUN2014'D,
				  '04JUN2015'D,
				  '26MAY2016'D,
				  '15JUN2017'D,
				  '31MAY2018'D,
				  '20JUN2019'D,
				  '11JUN2020'D) 
then event='Fronleichnam';
else if month(tag)=8 and day(tag)=15 then event='Maria Himmelfahrt';
else if month(tag)=10 and day(tag)=3 then event='Tag der Deutschen Einheit';
  else if tag in ('22NOV2000'D,
                  '21NOV2001'D,
				  '20NOV2002'D,
				  '19NOV2003'D,
				  '17NOV2004'D,
				  '16NOV2005'D,
				  '22NOV2006'D,
				  '21NOV2007'D,
				  '19NOV2008'D,
				  '18NOV2009'D,
				  '17NOV2010'D,
				  '16NOV2011'D,
				  '21NOV2012'D,
				  '20NOV2013'D,
				  '19NOV2014'D,
				  '18NOV2015'D,
				  '16NOV2016'D,
				  '22NOV2017'D,
				  '21NOV2018'D,
				  '20NOV2019'D,
				  '18NOV2018'D)
   then event='Buss- und Bettag';
else if month(tag)=10 and day(tag)=31 then event='Reformationstag, Halloween';
else if month(tag)=11 and day(tag)=1 then event='Allerheiligen';
else if month(tag)=12 and day(tag)=24 then event='Heiligabend';
else if month(tag)=12 and day(tag)=25 then event='1. Weihnachtsfeiertag';
else if month(tag)=12 and day(tag)=26 then event='2. Weihnachtsfeiertag';
else if month(tag)=12 and day(tag)=31 then event='Sylvester';
else if month(tag)=2 and day(tag)=14 then event='Valentinstag';
  else if tag in ('14MAY2000'D,
                  '13MAY2001'D,
                  '12MAY2002'D,
                  '11MAY2003'D,
                  '09MAY2004'D,
                  '08MAY2005'D,
                  '14MAY2006'D,
                  '13MAY2007'D,
                  '11MAY2008'D,
                  '10MAY2009'D,
                  '09MAY2010'D,
				  '08MAY2011'D,
				  '13MAY2012'D,
				  '12MAY2013'D,
				  '11MAY2014'D,
				  '10MAY2015'D,
				  '08MAY2016'D,
				  '14MAY2017'D,
				  '13MAY2018'D,
				  '12MAY2019'D,
				  '10MAY2020'D) 

then event='Muttertag';
else if month(tag)=12 and day(tag)=6 then event='Nikolaus';
  else if tag in ('02DEC2000'D,
                  '01DEC2001'D,
                  '30NOV2002'D,
                  '29NOV2003'D,
                  '27NOV2004'D,
                  '26NOV2005'D,
                  '25NOV2006'D,
                  '01DEC2007'D,
                  '29NOV2008'D,
                  '28NOV2009'D,
                  '27NOV2010'D,
                  '26NOV2011'D,
                  '01DEC2012'D,
				  '30NOV2013'D,
				  '29NOV2014'D,
				  '28NOV2015'D,
				  '26NOV2016'D,
				  '02DEC2017'D,
				  '01DEC2018'D,
				  '30NOV2019'D,
				  '28NOV2020'D)
  then event='1. Adventssamstag';
  else if tag in ('09DEC2000'D,
                  '08DEC2001'D,
                  '07DEC2002'D,
                  '06DEC2003'D,
                  '04DEC2004'D,
                  '03DEC2005'D,
                  '02DEC2006'D,
                  '08DEC2007'D,
                  '06DEC2008'D,
                  '05DEC2009'D,
                  '04DEC2010'D,
                  '03DEC2011'D,
				  '08DEC2012'D,
				  '07DEC2013'D,
				  '06DEC2014'D,
				  '05DEC2015'D,
				  '03DEC2016'D,
				  '09DEC2017'D,
				  '08DEC2018'D,
				  '07DEC2019'D,
				  '05DEC2020'D)
  then event='2. Adventssamstag';
  else if tag in ('16DEC2000'D,
                  '15DEC2001'D,
                  '14DEC2002'D,
                  '13DEC2003'D,
                  '11DEC2004'D,
                  '10DEC2005'D,
                  '09DEC2006'D,
                  '15DEC2007'D,
                  '13DEC2008'D,
                  '12DEC2009'D,
                  '11DEC2010'D,
				  '10DEC2011'D,
				  '15DEC2012'D,
				  '14DEC2013'D,
				  '13DEC2014'D,
				  '12DEC2015'D,
				  '10DEC2016'D,
				  '16DEC2017'D,
				  '15DEC2018'D,
				  '14DEC2019'D,
				  '12DEC2020'D) 
  then event='3. Adventssamstag';
  else if tag in ('23DEC2000'D,
                  '22DEC2001'D,
                  '21DEC2002'D,
                  '20DEC2003'D,
                  '18DEC2004'D,
                  '17DEC2005'D,
                  '16DEC2006'D,
                  '22DEC2007'D,
                  '20DEC2008'D,
                  '19DEC2009'D,
                  '18DEC2010'D,
				  '17DEC2011'D,
				  '22DEC2012'D,
				  '21DEC2013'D,
				  '20DEC2014'D,
				  '19DEC2015'D,
				  '17DEC2016'D,
				  '23DEC2017'D,
				  '22DEC2018'D,
				  '21DEC2019'D,
				  '19DEC2020'D) 
  then event='4. Adventssamstag';
  if tag in ('02JUN2000'D,
             '25MAY2001'D,
             '10MAY2002'D,
             '30MAY2003'D,
             '21MAY2004'D,
             '06MAY2005'D,
             '26MAY2006'D,
             '18MAY2007'D,
             '02MAY2008'D,
             '22MAY2009'D,
             '14MAY2010'D,
             '03JUN2011'D,
             '18MAY2012'D,
			 '10MAY2013'D,
			 '30MAY2014'D,
			 '15MAY2015'D,
			 '06MAY2016'D,
			 '26MAY2017'D,
			 '11MAY2018'D,
			 '31MAY2019'D,
			 '22MAY2020'D) 
   then event='Brückentag';
   else if tag in ('23JUN2000'D,
                   '15JUN2001'D,
                   '31MAY2002'D,
                   '20JUN2003'D,
                   '11JUN2004'D,
                   '27MAY2005'D,
                   '16JUN2006'D,
                   '08JUN2007'D,
                   '23MAY2008'D,
                   '12JUN2009'D,
                   '14JUN2010'D,
				   '24JUN2011'D,
				   '08JUN2012'D,
				   '31MAY2013'D,
				   '20JUN2014'D,
				   '05JUN2015'D,
				   '27MAY2016'D,
				   '16JUN2017'D,
				   '01JUN2018'D,
				   '21JUN2019'D,
				   '12JUN2020'D)
  then event='Brückentag';
  else if (day(vortag)=1 and month(vortag)=5 and weekday(tag)=6) OR 
           (day(folgetag)=1 and month(folgetag)=5 and weekday(tag)=2) then event='Brückentag';
   else if (day(vortag)=3 and month(vortag)=10 and weekday(tag)=6) OR 
           (day(folgetag)=3 and month(folgetag)=10 and weekday(tag)=2) then event='Brückentag';
   else if (day(vortag)=1 and month(vortag)=11 and weekday(tag)=6) OR 
           (day(folgetag)=1 and month(folgetag)=11 and weekday(tag)=2) then event='Brückentag';


   /* Bestimme Wochentag, Kalendermonat und Woche */
   if weekday(datum)=1 then wochentag='1. So';
   else if weekday(datum)=2 then wochentag='2. Mo';
   else if weekday(datum)=3 then wochentag='3. Di';
   else if weekday(datum)=4 then wochentag='4. Mi';
   else if weekday(datum)=5 then wochentag='5. Do';
   else if weekday(datum)=6 then wochentag='6. Fr';
   else if weekday(datum)=7 then wochentag='7. Sa';
   monat=month(datum);
   woche=week(datum);


   /* Dummy-Codierung für Zuordnung der Events zu Feiertagskategorien */
   if trim(event) in ('Neujahr',
                      'Karfreitag',
					  'Ostersonntag',
					  'Ostermontag',
					  'Maifeiertag',
					  'Pfingstsonntag',
					  'Pfingstmontag',
					  'Tag der Deutschen Einheit',
					  'Heiligabend',
					  '1. Weihnachtsfeiertag',
					  '2. Weihnachtsfeiertag',
					  'Sylvester')
	then gf_flag=1;
	else if trim (event) in ('Heilige Drei Könige',
	                         'Rosenmontag',
							 'Christi Himmelfahrt',
							 'Fronleichnam',
							 'Maria Himmelfahrt',
							 'Buss- und Bettag',
							 'Reformationstag, Halloween',
							 'Allerheiligen')
	then rf_flag=1;
	else if trim(event) eq 'Brückentag' then bt_flag=1;
	else if trim(event) in ('Valentinstag',
	                        'Muttertag',
							'Reformationstag, Halloween',
							'Nikolaus',
							'1. Adventssamstag',
							'2. Adventssamstag',
							'3. Adventssamstag',
							'4. Adventssamstag')
	then st_flag=1;

	array flags(4) gf_flag rf_flag bt_flag st_flag;

	do i=1 to 4;
     if missing(flags(i)) then flags{i}=0;
	end;
    
	total_flag=gf_flag+rf_flag;
	

/* Platzhalter-Modul für Tagesindividuelle Gewichte */

		/* Block für reguläre Wochentage */
		if wochentag='1. So' then wgt1=0.0;
        else if wochentag='2. Mo' then wgt1=1.0;
        else if wochentag='3. Di' then wgt1=1.0;
        else if wochentag='4. Mi' then wgt1=1.0;
        else if wochentag='5. Do' then wgt1=1.0;
        else if wochentag='6. Fr' then wgt1=1.0;
        else if wochentag='7. Sa' then wgt1=0.0;
      
		if trim(event)='' then wgt2=1;

		/* Block für gesetzliche Feiertage */
        else if trim(event) eq "Neujahr" then wgt2=0;
        else if trim(event) eq "Karfreitag" then wgt2=0;
        else if trim(event) eq "Ostermontag" then wgt2=0;
        else if trim(event) eq "Ostersonntag" then wgt2=0;
        else if trim(event) eq "Pfingstmontag" then wgt2=0;
        else if trim(event) eq "Pfingstsonntag" then wgt2=0;
        else if trim(event) eq "Maifeiertag" then wgt2=0;
        else if trim(event) eq "Tag der Deutschen Einheit" then wgt2=0;
        else if trim(event) eq "Heiligabend" then wgt2=0;
        else if trim(event) eq "1. Weihnachtsfeiertag" then wgt2=0; 
        else if trim(event) eq "2. Weihnachtsfeiertag" then wgt2=0;
        else if trim(event) eq "Sylvester" then wgt2=0; 
       
        /* Block für regionale (christliche) Feiertage */
        else if trim(event) eq "Heilige Drei Könige" then wgt2=1;
        else if trim(event) eq "Rosenmontag" then wgt2=1;
        else if trim(event) eq "Christi Himmelfahrt" then wgt2=0;
        else if trim(event) eq "Fronleichnam" then wgt2=0;
        else if trim(event) eq "Maria Himmelfahrt" then wgt2=1;
        else if trim(event) eq "Reformationstag, Halloween" then wgt2=1;
        else if trim(event) eq "Buss- und Bettag" then wgt2=1; 
        else if trim(event) eq "Allerheiligen" then wgt2=0; 

        /* Block für Brückentage */
        else if trim(event) eq "Brückentag" then wgt2=1; 
       
		/* Block für sonstige Retail-Tage */
        else if trim(event) eq "Valentinstag" then wgt2=1; 
        else if trim(event) eq "Muttertag" then wgt2=1;
        else if trim(event) eq "Nikolaus" then wgt2=1;
        else if trim(event) eq "1. Adventssamstag" then wgt2=1;
        else if trim(event) eq "2. Adventssamstag" then wgt2=1;
        else if trim(event) eq "3. Adventssamstag" then wgt2=1;
        else if trim(event) eq "4. Adventssamstag" then wgt2=1;
        
		/* Berechnung der Werktage */
		if trim(event)='' then wt_flag=wgt1;
		else if trim(event) ne '' then wt_flag=wgt2;

        format datum date9.;
    
	label datum='Kalenderdatum' 
	      event='Event-Beschreibung'
		  monat='Kalendermonat'
		  woche='Kalenderwoche'
		  wochentag='Wochentag'
		  gf_flag='Feiertag gesetzlich'
		  rf_flag='Feiertag regional'
		  bt_flag='Brückentag'
		  st_flag='Sonstiger Retail-Tag'
		  total_flag='Feiertag gesamt'
          wt_flag='Regulärer Werktag';
     drop i vortag folgetag tag wgt1 wgt2;

run;


/* Verdichten auf Monatsebene und Bestimmung der Anzahl Werktage */
proc timeseries data=tageskalender out=monatskalender;
  id datum interval=month accumulate=total setmiss=0 
         start='01jan2000'd  
         end  ='31dec2020'd; 
      var wt_flag; 
run;


/* Berechne Korrekturfaktoren für werktägliche Bereinigung, bezogen auf Basis-Monat Januar 2000 */
data monatskalender;
 set monatskalender;
 base=20;
 vkf=base/wt_flag;
 nkf=wt_flag/base;

 format vkf nkf 8.3;
 label datum='Monat'
       wt_flag='Anzahl Werktage'
	   vkf='Vorkorrekturfaktor'
	   nkf='Nachkorrekturfaktor';
 drop base;
run;

