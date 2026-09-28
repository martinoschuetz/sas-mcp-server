libname mafo "D:\DATEN\REWE\2015";

data mafo.temp (drop=i j k);
   array array1(20) y1-y20;
   array array2(12) x1-x12;
   
	 do i=1 to 607;
        respid=10000+i+1;
		do j=1 to 20;
	   		array1(j)=ranuni(1)*100;
	 	end;
		do k=1 to 12;
		    array2(k)=ranuni(1)*100;
		end;
				if i<250 then segment=1;
		else if i<453 then segment=2;
		else segment=3;
		
		output;
	end;
	run;
data mafo.temp2 (drop=x1 -- x12 /*y1 -- y20*/ segment);
  set mafo.temp;

  length respid 5 umb_a umb_b umb_c umb_d umb_e gmb_a gmb_b gmb_c gmb_d gmb_e 4 
         gesamt item1 item2 item3 item4 item5 item6 item7 item8 item9 4 anbieter $10
         verwendung $22

         bundesland $25 altersgruppe $16 geschlecht $12 berufsgruppe $37 familienstand $25
         bildung $38 ortsgroesse $30 wohnverhaeltnis $35 nationalitaet $25 
         haushaltsgroesse $12 anzahlkinder $20;

		 array array3(9) item1-item9; 
		 do l=1 to 9;
		   array3(l)=.;
		end;
  
  if y1<20 then umb_a =1; else umb_a=0;
  if y2<61 then umb_b =1; else umb_b=0;
  if y3<10 then umb_c =1; else umb_c=0;
  if y4<64 then umb_d =1; else umb_d=0;
  if y5< 6 then umb_e =1; else umb_e=0;

  if y6<70 or umb_a=1 then gmb_a =1; else gmb_a=0;
  if y7<91 or umb_b=1 then gmb_b =1; else gmb_b=0;
  if y8<39 or umb_c=1 then gmb_c =1; else gmb_c=0;
  if y9<80 or umb_d=1 then gmb_d =1; else gmb_d=0;
  if y10<25 or umb_e=1 then gmb_e =1; else gmb_e=0;


/* Verteilungen für Segment 1 */
  if segment eq 1 then do;

  anbieter='Anbieter A';
  
  if y11<35 then gesamt=1;
  else if y11<50 then gesamt=2;
  else if y11<72 then gesamt=3;
  else if y11<83 then gesamt=4;
  else gesamt=5;
  
  y12=y11+rannor(1)*100+50;
  y13=y11+rannor(1)*100+80;
  y14=y11+rannor(1)*100+50;
  y15=y11+rannor(1)*100-50;
  y16=y11+rannor(1)*100-90;
  y17=y11+rannor(1)*100-100;
  y18=y11+rannor(1)*100;
  y19=y11+rannor(1)*100;
  y20=y11+rannor(1)*100-100;
  y21=200;

  
 
  if x1<13 then bundesland='Bayern';
  else if x1<21 then bundesland='Baden-Württemberg';
  else if x1<25 then bundesland='Berlin';
  else if x1<28 then bundesland='Brandenburg';
  else if x1<29 then bundesland='Bremen';
  else if x1<31 then bundesland='Hamburg';
  else if x1<37 then bundesland='Hessen';
  else if x1<39 then bundesland='Mecklenburg-Vorpommern';
  else if x1<45 then bundesland='Niedersachsen';
  else if x1<62 then bundesland='Nordrhein-Westfalen';
  else if x1<69 then bundesland='Rheinland-Pfalz';
  else if x1<72 then bundesland='Saarland';
  else if x1<78 then bundesland='Sachsen';
  else if x1<83 then bundesland='Sachsen-Anhalt';
  else if x1<91 then bundesland='Schleswig-Holstein';
  else bundesland='Thüringen';
  
  if x2<4 then altersgruppe='Unter 18 Jahre';
  else if x2<28 then altersgruppe='Von 18-25 Jahre';
  else if x2<53 then altersgruppe='Von 26-35 Jahre';
  else if x2<74 then altersgruppe='Von 36-46 Jahre';
  else if x2<94 then altersgruppe='Von 47-65 Jahre';
  else altersgruppe='Über 65 Jahre';
  
  if x3<48 then geschlecht='Männlich';
  else geschlecht='Weiblich';

  if x4<12 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<41 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<42 then berufsgruppe='Landwirt';
  else if x4<50 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<86 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<92 then berufsgruppe='Hausfrau/-mann';
  else if x4<95 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else berufsgruppe='ohne Beschäftigung';
  
  if x5<43 then familienstand='ledig';
  else if x5<79 then familienstand='verheiratet';
  else if x5<85 then familienstand='geschieden/getrenntlebend';
  else familienstand='verwitwet';

  if x6<4 then bildung='ohne Abschluss';
  else if x6<42 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<61 then bildung='Abitur/Fachabitur';
  else bildung='Diplom/Magister/Promotion';
  
    if x7<40 then ortsgroesse='<50.000 Einwohner';
  else if x7<65 then ortsgroesse='50.000-250.000 Einwohner';
  else ortsgroesse='>250.000 Einwohner';

  if x8<45 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<86 then wohnverhaeltnis='Eigenheim';
  else wohnverhaeltnis='sonstige';

  if x9<10 then verwendung='> 3 mal pro Jahr';
  else if x9<30 then verwendung='ca. 2 -3 mal pro Jahr';
  else if x9<94 then verwendung='ca. 1 mal pro Jahr';
  else verwendung='ca. 1 mal pro Jahr';

  if x10<70 then nationalitaet='Deutsch';
  else if x10<90 then nationalitaet ='EU-Ausland';
  else nationalitaet='Sonstige';

  if x11<30 then haushaltsgroesse='1 Person';
  else if x11<71 then haushaltsgroesse='2 Personen';
  else haushaltsgroesse='> 2 Personen';

  if x12<50 then anzahlkinder='Keine Kinder';
  else if x12<78 then anzahlkinder='1-2 Kinder';
  else anzahlkinder='> 2 Kinder';

  end;

/* Verteilung für attraktives Segment */
  else if segment eq 2 then do;

  anbieter='Anbieter B';

   if y11<12 then gesamt=1;
  else if y11<42 then gesamt=2;
  else if y11<76 then gesamt=3;
  else if y11<90 then gesamt=4;
  else gesamt=5;

  y12=y11+rannor(1)*100-50;
  y13=y11+rannor(1)*100;
  y14=y11+rannor(1)*100-50;
  y15=y11+rannor(1)*100+60;
  y16=y11+rannor(1)*100+50;
  y17=y11+rannor(1)*100+50;
  y18=y11+rannor(1)*100;
  y19=y11+rannor(1)*100;
  y20=y11+rannor(1)*100-50;


  if x1<12 then bundesland='Bayern';
  else if x1<23 then bundesland='Baden-Württemberg';
  else if x1<27 then bundesland='Berlin';
  else if x1<29 then bundesland='Brandenburg';
  else if x1<30 then bundesland='Bremen';
  else if x1<34 then bundesland='Hamburg';
  else if x1<36 then bundesland='Hessen';
  else if x1<37 then bundesland='Mecklenburg-Vorpommern';
  else if x1<43 then bundesland='Niedersachsen';
  else if x1<63 then bundesland='Nordrhein-Westfalen';
  else if x1<69 then bundesland='Rheinland-Pfalz';
  else if x1<71 then bundesland='Saarland';
  else if x1<74 then bundesland='Sachsen';
  else if x1<82 then bundesland='Sachsen-Anhalt';
  else if x1<96 then bundesland='Schleswig-Holstein';
  else bundesland='Thüringen';
  
  if x2<3 then altersgruppe='Unter 18 Jahre';
  else if x2<21 then altersgruppe='Von 18-25 Jahre';
  else if x2<60 then altersgruppe='Von 26-35 Jahre';
  else if x2<85 then altersgruppe='Von 36-46 Jahre';
  else if x2<98 then altersgruppe='Von 47-65 Jahre';
  else altersgruppe='Über 65 Jahre';
  
  if x3<45 then geschlecht='Männlich';
  else geschlecht='Weiblich';

  if x4<1 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<54 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<55 then berufsgruppe='Landwirt';
  else if x4<89 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<97 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<98 then berufsgruppe='Hausfrau/-mann';
  else if x4<99 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else berufsgruppe='ohne Beschäftigung';
  
  if x5<12 then familienstand='ledig';
  else if x5<79 then familienstand='verheiratet';
  else if x5<81 then familienstand='geschieden/getrenntlebend';
  else familienstand='verwitwet';

  if x6<1 then bildung='ohne Abschluss';
  else if x6<12 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<50 then bildung='Abitur/Fachabitur';
  else bildung='Diplom/Magister/Promotion';
  
  
  if x7<20 then ortsgroesse='<50.000 Einwohner';
  else if x7<67 then ortsgroesse='50.000-250.000 Einwohner';
  else ortsgroesse='>250.000 Einwohner';

  if x8<12 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<95 then wohnverhaeltnis='Eigenheim';
  else wohnverhaeltnis='sonstige';

  if x9<23 then verwendung='> 3 mal pro Jahr';
  else if x9<50 then verwendung='ca. 2 -3 mal pro Jahr';
  else if x9<91 then verwendung='ca. 1 mal pro Jahr';
  else verwendung='ca. 1 mal pro Jahr';

  if x10<75 then nationalitaet='Deutsch';
  else if x10<93 then nationalitaet='EU-Ausland';
  else nationalitaet='Sonstige';

  if x11<10 then haushaltsgroesse='1 Person';
  else if x11<58 then haushaltsgroesse='2 Personen';
  else haushaltsgroesse='> 2 Personen';

  if x12<23 then anzahlkinder='Keine Kinder';
  else if x12<79 then anzahlkinder='1-2 Kinder';
  else anzahlkinder='> 2 Kinder';

 
  end;


/* Verteilung für unattraktives Segment */
  else if segment eq 3 then do;
  
  
  anbieter='Anbieter C';

  if y11<33 then gesamt=1;
  else if y11<60 then gesamt=2;
  else if y11<87 then gesamt=3;
  else if y11<99 then gesamt=4;
  else gesamt=5;
  
    
  y12=y11+rannor(1)*100;
  y13=y11+rannor(1)*100;
  y14=y11+rannor(1)*100;
  y15=y11+rannor(1)*100;
  y16=y11+rannor(1)*100;
  y17=y11+rannor(1)*100;
  y18=y11+rannor(1)*100+70;
  y19=y11+rannor(1)*100+50;
  y20=y11+rannor(1)*100-20;

 
  if x1<14 then bundesland='Bayern';
  else if x1<22 then bundesland='Baden-Württemberg';
  else if x1<29 then bundesland='Berlin';
  else if x1<32 then bundesland='Brandenburg';
  else if x1<35 then bundesland='Bremen';
  else if x1<39 then bundesland='Hamburg';
  else if x1<41 then bundesland='Hessen';
  else if x1<48 then bundesland='Mecklenburg-Vorpommern';
  else if x1<56 then bundesland='Niedersachsen';
  else if x1<78 then bundesland='Nordrhein-Westfalen';
  else if x1<82 then bundesland='Rheinland-Pfalz';
  else if x1<81 then bundesland='Saarland';
  else if x1<87 then bundesland='Sachsen';
  else if x1<96 then bundesland='Sachsen-Anhalt';
  else if x1<97 then bundesland='Schleswig-Holstein';
  else bundesland='Thüringen';
  
  if x2<37 then altersgruppe='Unter 18 Jahre';
  else if x2<60 then altersgruppe='Von 18-25 Jahre';
  else if x2<70 then altersgruppe='Von 26-35 Jahre';
  else if x2<82 then altersgruppe='Von 36-46 Jahre';
  else if x2<96 then altersgruppe='Von 47-65 Jahre';
  else altersgruppe='Über 65 Jahre';
  
  if x3<67 then geschlecht='Männlich';
  else geschlecht='Weiblich';

  if x4<45 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<54 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<59 then berufsgruppe='Landwirt';
  else if x4<60 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<80 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<83 then berufsgruppe='Hausfrau/-mann';
  else if x4<93 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else berufsgruppe='ohne Beschäftigung';
  
  if x5<69 then familienstand='ledig';
  else if x5<73 then familienstand='verheiratet';
  else if x5<80 then familienstand='geschieden/getrenntlebend';
  else familienstand='verwitwet';

  if x6<40 then bildung='ohne Abschluss';
  else if x6<79 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<89 then bildung='Abitur/Fachabitur';
  else bildung='Diplom/Magister/Promotion';
    
  if x7<21 then ortsgroesse='<50.000 Einwohner';
  else if x7<66 then ortsgroesse='50.000-250.000 Einwohner';
  else ortsgroesse='>250.000 Einwohner';

  if x8<80 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<91 then wohnverhaeltnis='Eigenheim';
  else wohnverhaeltnis='sonstige';

  if x9<8 then verwendung='> 3 mal pro Jahr';
  else if x9<20 then verwendung='ca. 2 -3 mal pro Jahr';
  else if x9<83 then verwendung='ca. 1 mal pro Jahr';
  else verwendung='ca. 1 mal pro Jahr';

  if x10<74 then nationalitaet='Deutsch';
  else if x10<92 then nationalitaet='EU-Ausland';
  else nationalitaet='Sonstige';

  if x11<49 then haushaltsgroesse='1 Person';
  else if x11<68 then haushaltsgroesse='2 Personen';
  else haushaltsgroesse='> 2 Personen';

  if x12<70 then anzahlkinder='Keine Kinder';
  else if x12<79 then anzahlkinder='1-2 Kinder';
  else anzahlkinder='> 2 Kinder';

 
  end;
  
  
/* Ende des Codes zur Manipulation */







  /* Business-Rules*/
  if haushaltsgroesse='1 Person' then anzahlkinder='Keine Kinder';
  if anzahlkinder='> 2 Kinder' then haushaltsgroesse='> 2 Personen';
  if familienstand='verwitwet' then altersgruppe='Über 65 Jahre';
  if berufsgruppe='Schüler/Auszubildender/Student' then bildung='ohne Abschluss';
  if berufsgruppe in ('Ltd. Angestellter, Geschäftsführer','Freiberufler/Selbstd. Unternehmer') 
     then bildung='Diplom/Magister/Promotion';

  if segment=1 then gmb_a=1;
  if segment=2 then gmb_b=1;
  if segment=3 then gmb_c=1;

  label 
        respid ='Respondent-ID'
		gesamt='Gesamtzufriedenheit'
		item1='Anzahl akzeptierender Geschäfte'
        item2='Höhe der Gebüren'
		item3='Flexibilität der Raten-Konditionen'
		item4='Qualität der Aktionsangebote'
		item5='Angebot an Zusatzversicherungen'
		item6='Übersichtlichkeit der Abrechnungen'
		item7='Zügigkeit der Abwicklung bei Reklamationen'
		item8='Freundlichkeit des Callcenter-Personals'
		item9='Attraktivität des Karten-Designs'
		anbieter='Hauptsächlich verwendeter Anbieter'
		umb_a ='Ungestützte Bekanntheit für Anbieter A'
        umb_b ='Ungestützte Bekanntheit für Anbieter B'
		umb_c ='Ungestützte Bekanntheit für Anbieter C'
		umb_d ='Ungestützte Bekanntheit für Anbieter D'
		umb_e ='Ungestützte Bekanntheit für Anbieter E'
		gmb_a ='Gestützte Bekanntheit für Anbieter A'
        gmb_b ='Gestützte Bekanntheit für Anbieter B'
		gmb_c ='Gestützte Bekanntheit für Anbieter C'
		gmb_d ='Gestützte Bekanntheit für Anbieter D'
		gmb_e ='Gestützte Bekanntheit für Anbieter E'
        bundesland='Bundesland'
        altersgruppe='Altersgruppe'
		geschlecht='Geschlecht'
		berufsgruppe='Berufsgruppe'
		familienstand='Familienstand'
		bildung='Bildungsstand'
		ortsgroesse='Ortsgrößenklasse'
		wohnverhaeltnis='Wohnverhältnis'
		verwendung='Häufigkeit der Verwendung'
		nationalitaet='Staatsangehörigkeit'
        haushaltsgroesse='Haushaltsgröße'
        anzahlkinder='Anzahl Kinder im Haushalt';

  run;


proc means data=mafo.temp2 noprint;
 output out = mafo.aggdata 
    mean(y12--y20)=my12 my13 my14 my15 my16 my17 my18 my19 my20
     std(y12--y20)=sy12 sy13 sy14 sy15 sy16 sy17 sy18 sy19 sy20
;
  var y12--y20;
  by anbieter;
run;


data mafo.final (drop=_TYPE_ _FREQ_ y1--y20 y21 my12--my20 sy12--sy20 l j);
  merge mafo.temp2 mafo.aggdata;
  by anbieter;
  array a (9) y12-y20;
  array b (9) my12-my20;
  array c (9) sy12-sy20;
  array d (9) item1-item9;
  /* do j=1 to 9;
	if a(j)<b(j)-1.5*c(j) then d(j)=1; 
    else if a(j)<b(j)-0.5*c(j) then d(j)=2; 
	else if a(j)<b(j)+0.5*c(j) then d(j)=3; 
    else if a(j)<b(j)+1.5*c(j) then d(j)=4; 
   else d(j)=5; 
  end;
  */
  do j=1 to 9;
  if a(j)<5 then d(j)=1;
  else if a(j)<50 then d(j)=2;
  else if a(j)<120 then d(j)=3;
  else if a(j)<150 then d(j)=4;
  else d(j)=5;
  end;


run;

proc freq data=mafo.final;
 table (item1--item9)*anbieter /NOROW NOPERCENT NOFREQ;
run;

proc means data=mafo.final mean;
 var item1--item9;
 class anbieter;
run;

/* Aufräumen aller nicht mehr benötigten Dateien */ 
proc datasets library=mafo nolist;
   delete temp temp2 aggdata /memtype=DATA
;
quit;

proc export data=mafo.final outfile='D:\DATEN\UMFRAGE\daten.csv'
     DBMS = DLM REPLACE;
	 DELIMITER=',';
run;
