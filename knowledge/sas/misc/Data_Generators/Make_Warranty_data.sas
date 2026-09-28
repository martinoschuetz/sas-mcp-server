libname opel "C:\Opel";
data opel.temp0 (drop=i xbaugruppe xwerk xregion xcode y z log_dauer);
do i=1 to 15010;
    length id 6 baugruppe $12 werk $7 region $20 laborcode $8 land $30 modell $16;
	ID=1000000+i*100+int(ranuni(1)*50);
	xbaugruppe=ranuni(1)*100;
	xwerk=ranuni(2)*100;
	xregion=ranuni(4)*100;
	xcode=ranuni(5)*100;

    if xbaugruppe<30 then baugruppe='Baugruppe A';
	else if xbaugruppe<40 then baugruppe='Baugruppe B';
	else if xbaugruppe<47 then baugruppe='Baugruppe C';
	else if xbaugruppe<64 then baugruppe='Baugruppe D';
	else if xbaugruppe<80 then baugruppe='Baugruppe E';
	else if xbaugruppe<95 then baugruppe='Baugruppe F';
	else baugruppe='Baugruppe G';
	if xWerk<30 then Werk='Werk A';
	else if xWerk<70 then Werk='Werk B';
	else Werk='Werk C';

	if baugruppe='Baugruppe A' and xcode<20 then laborcode='Code A-1';
    else if baugruppe='Baugruppe A' and xcode<50 then laborcode='Code A-2';
	else if baugruppe='Baugruppe A' and xcode<60 then laborcode='Code A-3';
	else if baugruppe='Baugruppe A' and xcode<80 then laborcode='Code A-4';
	else if baugruppe='Baugruppe A' and xcode<90 then laborcode='Code A-5';
	else if baugruppe='Baugruppe A' and xcode<95 then laborcode='Code A-6';
	else if baugruppe='Baugruppe A' then laborcode='Code A-7';

    if baugruppe='Baugruppe B' and xcode<5 then laborcode='Code B-1';
    else if baugruppe='Baugruppe B' and xcode<15 then laborcode='Code B-2';
	else if baugruppe='Baugruppe B' and xcode<40 then laborcode='Code B-3';
	else if baugruppe='Baugruppe B' and xcode<80 then laborcode='Code B-4';
	else if baugruppe='Baugruppe B' and xcode<90 then laborcode='Code B-5';
	else if baugruppe='Baugruppe B' and xcode<98 then laborcode='Code B-6';
	else if baugruppe='Baugruppe B' then laborcode='Code B-7';

    if baugruppe='Baugruppe C' and xcode<8 then laborcode='Code C-1';
    else if baugruppe='Baugruppe C' and xcode<13 then laborcode='Code C-2';
	else if baugruppe='Baugruppe C' and xcode<23 then laborcode='Code C-3';
	else if baugruppe='Baugruppe C' and xcode<40 then laborcode='Code C-4';
	else if baugruppe='Baugruppe C' and xcode<68 then laborcode='Code C-5';
	else if baugruppe='Baugruppe C' and xcode<81 then laborcode='Code C-6';
	else if baugruppe='Baugruppe C' and xcode<88 then laborcode='Code C-7';
	else if baugruppe='Baugruppe C' and xcode<94 then laborcode='Code C-8';
	else if baugruppe='Baugruppe C' then laborcode='Code C-9';

    if baugruppe='Baugruppe D' and xcode<10 then laborcode='Code D-1';
    else if baugruppe='Baugruppe D' and xcode<12 then laborcode='Code D-2';
	else if baugruppe='Baugruppe D' and xcode<26 then laborcode='Code D-3';
	else if baugruppe='Baugruppe D' and xcode<30 then laborcode='Code D-4';
	else if baugruppe='Baugruppe D' and xcode<40 then laborcode='Code D-5';
	else if baugruppe='Baugruppe D' and xcode<50 then laborcode='Code D-6';
	else if baugruppe='Baugruppe D' and xcode<86 then laborcode='Code D-7';
	else if baugruppe='Baugruppe D' and xcode<95 then laborcode='Code D-8';
	else if baugruppe='Baugruppe D' then laborcode='Code D-9';

	if baugruppe='Baugruppe E' and xcode<73 then laborcode='Code E-1';
    else if baugruppe='Baugruppe E' and xcode<79 then laborcode='Code E-2';
	else if baugruppe='Baugruppe E' and xcode<82 then laborcode='Code E-3';
	else if baugruppe='Baugruppe E' and xcode<89 then laborcode='Code E-4';
	else if baugruppe='Baugruppe E' then laborcode='Code E-5';

	if baugruppe='Baugruppe F' and xcode<60 then laborcode='Code F-1';
    else if baugruppe='Baugruppe F' and xcode<68 then laborcode='Code F-2';
	else if baugruppe='Baugruppe F' and xcode<89 then laborcode='Code F-3';
	else if baugruppe='Baugruppe F' and xcode<99 then laborcode='Code F-4';
	else if baugruppe='Baugruppe F' then laborcode='Code F-5';

	if baugruppe='Baugruppe G' and xcode<77 then laborcode='Code G-1';
    else if baugruppe='Baugruppe G' and xcode<89 then laborcode='Code G-2';
	else if baugruppe='Baugruppe G' and xcode<99 then laborcode='Code G-3';
	else if baugruppe='Baugruppe G' then laborcode='Code G-4';
    
	if xregion<15 then region='Vertriebsgebiet 1';
    else if xregion<28 then region='Vertriebsgebiet 2';
	else if xregion<40 then region='Vertriebsgebiet 3';
	else if xregion<50 then region='Vertriebsgebiet 4';
    else if xregion<65 then region='Vertriebsgebiet 5';
	else if xregion<77 then region='Vertriebsgebiet 6';
	else if xregion<87 then region='Vertriebsgebiet 7';
	else if xregion<93 then region='Vertriebsgebiet 8';
	else region='Vertriebsgebiet 9';

	prod_dat='01DEC1999'd+i/10;
	y=int((ranexp(12345)/12)*100)+5;
	if werk='Werk B' then ausf_dat=prod_dat+y*30;
	else ausf_dat=prod_dat+y*30+60;
	if ausf_dat gt '21Sep2005'd then ausf_dat='21Sep2005'd-int(ranuni(1)*5);
	format prod_dat ausf_dat date9.;	
    z=intck('week4',prod_dat,ausf_dat); 
	kmstand=int(25000+z*5000+rannor(1)*700);
	log_dauer=log(z);
	land='Deutschland';
	modell ='XYZ Sportcoupe';

    if i=15001 then do;
      land='Frankreich';
	  modell='XYZ Limousine';
	end;
    if i=15002 then do;
      land='Benelux';
	  modell='XYZ Limousine';
	end; 
    if i=15003 then do;
      land='Italien';
	  modell='XYZ Limousine';
	end;
    if i=15004 then do;
      land='Spanien/Portugal';
	  modell='XYZ Limousine';
	end;
    if i=15005 then do;
      land='Österreich/Schweiz';
	  modell='XYZ Limousine';
	end;

	if i=15006 then do;
      land='Großbritannien';
	  modell='XYZ Limousine';
	end;
    if i=15007 then do;
      land='Skandinavien';
	  modell='XYZ Limousine';
	end;
   if i=15008 then do;
      land='Osteuropa';
	  modell='XYZ Limousine';
	end;
   if i=15009 then do;
      land='Türkei';
	  modell='XYZ Limousine';
	end;
   if i=15010 then do;
      land='Griechenland';
	  modell='XYZ Limousine';
	end;



	label ID = 'Fahrzeug-ID'
	      region ='Werkstattregion'
		  baugruppe='Baugruppe'
		  werk='Produktionswerk'
		  laborcode='Laborcode'
          prod_dat='Fertigungsdatum'
          ausf_dat='Eintrittsdatum'
		  service_zeit='Zeitraum in Monaten'
		  kmstand='Kilometerstand'
		  modell='Fahrzeugmodell'
		  land='Land'
          ;
  

output;
end;


run;
