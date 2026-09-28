libname CLV "D:\DATEN";

data clv.temp (drop=Alter Geschlecht Erwerbst_tig Familienstatus Postleitzahl);
   set clv.segmentprofile;
run;

data clv.finaldata (drop=x1 -- x12);
  set clv.temp;

  length bundesland $25 altersgruppe $16 geschlecht $12 berufsgruppe $37 familienstand $25
         bildung $38 ortsgroesse $30 wohnverhaeltnis $35 pkwbesitz $18 wohnsitzdauer $25 
         haushaltsgroesse $12 anzahlkinder $20;
  x1=ranuni(1)*100;
  x2=ranuni(1)*100;
  x3=ranuni(1)*100;
  x4=ranuni(1)*100;
  x5=ranuni(1)*100;
  x6=ranuni(1)*100;
  x7=ranuni(1)*100;
  x8=ranuni(1)*100;
  x9=ranuni(1)*100;
  x10=ranuni(1)*100;
  x11=ranuni(1)*100;
  x12=ranuni(1)*100;

/* Wahrscheinlichkeiten für Grundgesamtheit bzw Segmente 100,200, 300, 1000 */
  if endsegmentierung in (100,200,300, 1000) then do;
  
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
  else if x1<88 then bundesland='Schleswig-Holstein';
  else if x1<93 then bundesland='Thüringen';
  
  if x2<4 then altersgruppe='Unter 18 Jahre';
  else if x2<28 then altersgruppe='Von 18-25 Jahre';
  else if x2<53 then altersgruppe='Von 26-35 Jahre';
  else if x2<74 then altersgruppe='Von 36-46 Jahre';
  else if x2<90 then altersgruppe='Von 47-65 Jahre';
  else if x2<95 then altersgruppe='Über 65 Jahre';
  
  if x3<48 then geschlecht='Männlich';
  else if x3<95 then geschlecht='Weiblich';

  if x4<12 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<41 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<42 then berufsgruppe='Landwirt';
  else if x4<50 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<86 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<92 then berufsgruppe='Hausfrau/-mann';
  else if x4<95 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else if x4<98 then berufsgruppe='ohne Beschäftigung';
  
  if x5<43 then familienstand='ledig';
  else if x5<79 then familienstand='verheiratet';
  else if x5<85 then familienstand='geschieden/getrenntlebend';
  else if x5<91 then familienstand='verwitwet';

  if x6<4 then bildung='ohne Abschluss';
  else if x6<42 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<61 then bildung='Abitur/Fachabitur';
  else if x6<92 then bildung='Diplom/Magister/Promotion';
  
    if x7<40 then ortsgroesse='<50.000 Einwohner';
  else if x7<65 then ortsgroesse='50.000-250.000 Einwohner';
  else if x7<99 then ortsgroesse='>250.000 Einwohner';

  if x8<45 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<86 then wohnverhaeltnis='Eigenheim';
  else if x8<89 then wohnverhaeltnis='sonstige';

  if x9<60 then pkwbesitz='Eigenes KFZ';
  else if x9<89 then pkwbesitz='Kein eigenes KFZ';

  if x10<20 then wohnsitzdauer='< 1 Jahr';
  else if x10<60 then wohnsitzdauer='1-5 Jahre';
  else if x10<98 then wohnsitzdauer='> 5 Jahre';

  if x11<30 then haushaltsgroesse='1 Person';
  else if x11<71 then haushaltsgroesse='2 Personen';
  else if x11<98 then haushaltsgroesse='> 2 Personen';

  if x12<50 then anzahlkinder='Keine Kinder';
  else if x12<78 then anzahlkinder='1-2 Kinder';
  else if x12<98 then anzahlkinder='> 2 Kinder';

  end;

/* Wahrscheinlichkeiten für attraktive Segmente*/
  else if endsegmentierung in (2000,3000) then do;
  
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
  else if x1<92 then bundesland='Schleswig-Holstein';
  else if x1<93 then bundesland='Thüringen';
  
  if x2<3 then altersgruppe='Unter 18 Jahre';
  else if x2<21 then altersgruppe='Von 18-25 Jahre';
  else if x2<60 then altersgruppe='Von 26-35 Jahre';
  else if x2<85 then altersgruppe='Von 36-46 Jahre';
  else if x2<98 then altersgruppe='Von 47-65 Jahre';
  else if x2<99 then altersgruppe='Über 65 Jahre';
  
  if x3<45 then geschlecht='Männlich';
  else if x3<97 then geschlecht='Weiblich';

  if x4<1 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<54 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<55 then berufsgruppe='Landwirt';
  else if x4<89 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<97 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<98 then berufsgruppe='Hausfrau/-mann';
  else if x4<99 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else if x4<100 then berufsgruppe='ohne Beschäftigung';
  
  if x5<12 then familienstand='ledig';
  else if x5<79 then familienstand='verheiratet';
  else if x5<81 then familienstand='geschieden/getrenntlebend';
  else if x5<96 then familienstand='verwitwet';

  if x6<1 then bildung='ohne Abschluss';
  else if x6<12 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<50 then bildung='Abitur/Fachabitur';
  else if x6<98 then bildung='Diplom/Magister/Promotion';
  
  
  if x7<20 then ortsgroesse='<50.000 Einwohner';
  else if x7<67 then ortsgroesse='50.000-250.000 Einwohner';
  else if x7<99 then ortsgroesse='>250.000 Einwohner';

  if x8<12 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<95 then wohnverhaeltnis='Eigenheim';
  else if x8<96 then wohnverhaeltnis='sonstige';

  if x9<89 then pkwbesitz='Eigenes KFZ';
  else if x9<97 then pkwbesitz='Kein eigenes KFZ';

  if x10<5 then wohnsitzdauer='< 1 Jahr';
  else if x10<50 then wohnsitzdauer='1-5 Jahre';
  else if x10<98 then wohnsitzdauer='> 5 Jahre';

  if x11<10 then haushaltsgroesse='1 Person';
  else if x11<58 then haushaltsgroesse='2 Personen';
  else if x11<98 then haushaltsgroesse='> 2 Personen';

  if x12<23 then anzahlkinder='Keine Kinder';
  else if x12<79 then anzahlkinder='1-2 Kinder';
  else if x12<98 then anzahlkinder='> 2 Kinder';

 
  end;


/* Wahrscheinlichkeiten für unattraktive Segmente*/
  else if endsegmentierung in (10,20,30) then do;
  
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
  else if x1<100 then bundesland='Thüringen';
  
  if x2<37 then altersgruppe='Unter 18 Jahre';
  else if x2<60 then altersgruppe='Von 18-25 Jahre';
  else if x2<70 then altersgruppe='Von 26-35 Jahre';
  else if x2<82 then altersgruppe='Von 36-46 Jahre';
  else if x2<91 then altersgruppe='Von 47-65 Jahre';
  else if x2<99 then altersgruppe='Über 65 Jahre';
  
  if x3<67 then geschlecht='Männlich';
  else if x3<98 then geschlecht='Weiblich';

  if x4<45 then berufsgruppe='Schüler/Auszubildender/Student';
  else if x4<54 then berufsgruppe='Freiberufler/Selbstd. Unternehmer';
  else if x4<59 then berufsgruppe='Landwirt';
  else if x4<60 then berufsgruppe='Ltd. Angestellter, Geschäftsführer';
  else if x4<80 then berufsgruppe='Angestellter/Facharbeiter/Handwerker';
  else if x4<83 then berufsgruppe='Hausfrau/-mann';
  else if x4<93 then berufsgruppe='Ungelernter Arbeiter/Hilfskraft';
  else if x4<100 then berufsgruppe='ohne Beschäftigung';
  
  if x5<69 then familienstand='ledig';
  else if x5<73 then familienstand='verheiratet';
  else if x5<80 then familienstand='geschieden/getrenntlebend';
  else if x5<96 then familienstand='verwitwet';

  if x6<40 then bildung='ohne Abschluss';
  else if x6<79 then bildung='Realschul-/Hauptschulabschluss';
  else if x6<89 then bildung='Abitur/Fachabitur';
  else if x6<93 then bildung='Diplom/Magister/Promotion';
  
  
  if x7<21 then ortsgroesse='<50.000 Einwohner';
  else if x7<66 then ortsgroesse='50.000-250.000 Einwohner';
  else if x7<99 then ortsgroesse='>250.000 Einwohner';

  if x8<80 then wohnverhaeltnis='Wohnung zur Miete';
  else if x8<91 then wohnverhaeltnis='Eigenheim';
  else if x8<99 then wohnverhaeltnis='sonstige';

  if x9<10 then pkwbesitz='Eigenes KFZ';
  else if x9<98 then pkwbesitz='Kein eigenes KFZ';

  if x10<34 then wohnsitzdauer='< 1 Jahr';
  else if x10<80 then wohnsitzdauer='1-5 Jahre';
  else if x10<99 then wohnsitzdauer='> 5 Jahre';

  if x11<49 then haushaltsgroesse='1 Person';
  else if x11<68 then haushaltsgroesse='2 Personen';
  else if x11<99 then haushaltsgroesse='> 2 Personen';

  if x12<70 then anzahlkinder='Keine Kinder';
  else if x12<79 then anzahlkinder='1-2 Kinder';
  else if x12<98 then anzahlkinder='> 2 Kinder';

 
  end;


/* Ende des Codes zur Manipulation */

 
  /* Business-Rules*/
  if haushaltsgroesse='1 Person' then anzahlkinder='Keine Kinder';
  if anzahlkinder='> 2 Kinder' then haushaltsgroesse='> 2 Personen';
  if berufsgruppe='Schüler/Auszubildender/Student' then bildung='ohne Abschluss';
  if berufsgruppe in ('Ltd. Angestellter, Geschäftsführer','Freiberufler/Selbstd. Unternehmer') 
     then bildung='Diplom/Magister/Promotion';
 
  label bundesland       ='Bundesland'
        altersgruppe     ='Altersgruppe'
		geschlecht       ='Geschlecht'
		berufsgruppe     ='Berufsgruppe'
		familienstand    ='Familienstand'
		bildung          ='Bildungsstand'
		ortsgroesse      ='Ortsgrößenklasse'
		wohnverhaeltnis  ='Wohnverhältnis'
		pkwbesitz        ='PKW-Besitz'
		wohnsitzdauer    ='Ansässigkeit am derzeitigen Wohnsitz'
        haushaltsgroesse ='Haushaltsgröße'
        anzahlkinder     ='Anzahl Kinder im Haushalt';

  run;


proc freq data=clv.finaldata;
 table (bundesland 
        altersgruppe
        geschlecht
        berufsgruppe
        familienstand
        bildung
        ortsgroesse 
        wohnverhaeltnis
        pkwbesitz
        wohnsitzdauer
        haushaltsgroesse
        anzahlkinder)
        *endsegmentierung /NOCOL NOFREQ NOPERCENT
;
run;

