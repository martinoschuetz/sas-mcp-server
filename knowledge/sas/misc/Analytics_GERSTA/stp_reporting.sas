/* Stored Process für Paulaner */

%let _ODSSTYLE=d3d;


%stpbegin;
options dflang=german;
%let path=C:\Daten\Paul\Work;
libname pl "C:\Daten\Paul\Work";



/* Generiere endgültige Prognosen auf Monatsbasis */

%let monate=PL3;
libname m_fc "C:\Sas\temp\projects\&monate\hierarchy\leaf";

proc transpose data=m_fc.finalfor (keep=artikel datum predict) 
               out=pl.monthly_forecasts (drop=_name_ _label_
                   rename=());
by Artikel;
var predict;
run;


title j=center height=16pt color=black "Abverkaufsprognose in Hl";


footnote;
footnote j=left height=10pt color=black "Erstellt am %sysfunc(today(),eurdfdd10.) um %sysfunc(time(),time8.) Uhr";

title2 j=center height=10pt color=black "Monatswerte";
title3 j=center height=10pt '<a href="file://C:\Daten\Paul\Work\forecasts_monthly.csv">Monatsprognosen herunterladen</a>';


PROC PRINT DATA=pl.monthly_forecasts noobs label 
   STYLE(HEADER)={BACKGROUND=lightgrey 
                  FOREGROUND=black 
                  FONT_SIZE=10pt
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=2pt}
   STYLE(DATA)={BACKGROUND=white
                  FOREGROUND=black 
                  FONT_SIZE=10pt
				  FONT_WEIGHT=LIGHT
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=0.5pt};
   var artikel COL1 -- COL15;
   label Artikel ='Artikelnummer'
         COL1='Jul 2005'
         COL2='Aug 2005' 
         COL3='Sep 2005'
         COL4='Okt 2005'
         COL5='Nov 2005'
         COL6='Dez 2005'
         COL7='Jan 2006' 
         COL8='Feb 2006'
         COL9='Mar 2006'
         COL10='Apr 2006'
         COL11='Mai 2006'
         COL12='Jun 2006'
         COL13='Jul 2006'
		 COL14='Aug 2006'
		 COL15='Sep 2006';
RUN;


data m_fc.temp1 (keep=artikel monat demand);
   set m_fc.finalfor;
   monat=datum;
   demand=predict;
   format monat monyy7. demand 8.4;
   label artikel='Artikelnummer' monat='Monat' demand='Prognosewert';
run;

PROC EXPORT DATA= m_fc.temp1
            OUTFILE= "&path\forecasts_monthly.csv" 
            DBMS=DLM REPLACE;
            DELIMITER=','; 
			
RUN;






















title;




/* Generiere endgültige Prognosen auf Wochenbasis */

%let wochen=PL2;

libname w_fc "C:\Sas\temp\projects\&wochen\hierarchy\leaf";

proc transpose data=w_fc.finalfor (keep=artikel datum predict) 
               out=pl.weekly_forecasts (drop=_name_ _label_);
by Artikel;
var predict;
run;

title2 j=center height=10pt color=black "Wochenwerte";
title3 j=center height=10pt '<a href="file://C:\Daten\Paul\Work\forecasts_weekly.csv">Wochenprognosen herunterladen</a>';


PROC PRINT DATA=pl.weekly_forecasts noobs label 
   STYLE(HEADER)={BACKGROUND=lightgrey 
                  FOREGROUND=black 
                  FONT_SIZE=10pt
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=2pt}
   STYLE(DATA)={BACKGROUND=white
                  FOREGROUND=black 
                  FONT_SIZE=10pt
				  FONT_WEIGHT=LIGHT
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=0.5pt};
   var artikel COL1 -- COL10;
   label Artikel ='Artikelnummer'
         COL1='KW25 2005'
         COL2='KW26 2005'
         COL3='KW27 2005'
	     COL4='KW28 2005'
         COL5='KW29 2005'
         COL6='KW30 2005'
         COL7='KW31 2005'
         COL8='KW32 2005'
         COL9='KW33 2005'
         COL10='KW34 2005';
RUN;

data w_fc.temp2 (keep=artikel woche demand);
   set w_fc.finalfor;
   woche=datum;
   if prebfovr=predict then demand=predict-1; else demand=predict;
   format woche eurdfdd10. demand 8.4;
   label artikel='Artikelnummer' woche='Woche' demand='Prognosewert';
   if datum <'26Jun2005'd OR datum>'31Aug2005'd then delete;
run;

PROC EXPORT DATA= w_fc.temp2
            OUTFILE= "&path\forecasts_weekly.csv" 
            DBMS=DLM REPLACE;
            DELIMITER=','; 
			
RUN;


















/* Generiere endgültige Prognosen auf Tagesbasis */


/* Disaggregiere Wochenprognose auf Tagesebene */

data w_fc.copy1;
 set w_fc.finalfor;
 datum=datum+1;
run; 

data w_fc.copy2;
 set w_fc.finalfor;
 datum=datum+2;
run; 
data w_fc.copy3;
 set w_fc.finalfor;
 datum=datum+3;
run; 
data w_fc.copy4;
 set w_fc.finalfor;
 datum=datum+4;
run; 
data w_fc.copy5;
 set w_fc.finalfor;
 datum=datum+5;
run; 
data w_fc.copy6;
 set w_fc.finalfor;
 datum=datum+6;
run; 
data pl.merged;
 set w_fc.finalfor 
     w_fc.copy1
     w_fc.copy2
     w_fc.copy3
     w_fc.copy4
     w_fc.copy5
     w_fc.copy6;
  format datum date9.0;
run;


proc sort data=pl.merged;
  by artikel datum;
run;

data pl.merged2;
  merge pl.merged pl.profiles;
  by artikel;
run;

data pl.daily_forecasts_raw (keep=artikel datum demand where=(datum>="25Jun2005"d and datum<="30Sep2005"d));
  set pl.merged2;
  demand=predict;
  wochentag=weekday(datum);
 if wochentag=1 then demand=predict*p_sun;
 else if wochentag=2 then demand=predict*p_mon;
 else if wochentag=3 then demand=predict*p_tue;
 else if wochentag=4 then demand=predict*p_wed;
 else if wochentag=5 then demand=predict*p_thu;
 else if wochentag=6 then demand=predict*p_fri;
 else if wochentag=7 then demand=predict*p_sat;
 
run;


proc transpose data=pl.daily_forecasts_raw (keep=artikel datum demand) 
               out=pl.daily_forecasts;
by Artikel;
var demand;
run;


title2 j=center height=10pt color=black "Tageswerte";
title3 j=center height=10pt '<a href="file://C:\Daten\Paul\Work\forecasts_daily.csv">Tagesprognosen herunterladen</a>';

PROC PRINT DATA=pl.daily_forecasts noobs label
   STYLE(HEADER)={BACKGROUND=lightgrey 
                  FOREGROUND=black 
                  FONT_SIZE=10pt
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=2pt}
   STYLE(DATA)={BACKGROUND=white
                  FOREGROUND=black 
                  FONT_SIZE=10pt
				  FONT_WEIGHT=LIGHT
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=0.5pt};
   var artikel COL1 -- COL20;
   label Artikel ='Artikelnummer'
         COL1='01.07.2005'
         COL2='02.07.2005'
		 COL3='03.07.2005'
		 COL4='04.07.2005'
		 COL5='05.07.2005'
		 COL6='06.07.2005'
		 COL7='07.07.2005'
		 COL8='08.07.2005'
		 COL9='09.07.2005'
		 COL10='10.07.2005'
		 COL11='11.07.2005'
		 COL12='12.07.2005'
		 COL13='13.07.2005'
		 COL14='14.07.2005'
		 COL15='15.07.2005'
		 COL16='16.07.2005'
		 COL17='17.07.2005'
		 COL18='18.07.2005'
		 COL19='19.07.2005'
		 COL20='20.07.2005'
		 COL21='21.07.2005'
		 COL22='22.07.2005'
		 COL23='23.07.2005'
		 COL24='24.07.2005'
		 COL25='25.07.2005'
		 COL26='26.07.2005'
		 COL27='27.07.2005'
		 COL28='28.07.2005'
		 COL29='29.07.2005'
		 COL30='30.07.2005'
		 COL31='31.07.2005'
;
RUN;

data w_fc.temp3 (keep=artikel datum demand);
   set pl.daily_forecasts_raw;
   format datum eurdfdd10. predict 8.4;
   label artikel='Artikelnummer' datum='Tag' demand='Prognosewert';
   if datum<'01Jul2005'd OR datum>'20Jul2005'd then delete;
run;

PROC EXPORT DATA= w_fc.temp3
            OUTFILE= "&path\forecasts_daily.csv" 
            DBMS=DLM REPLACE;
            DELIMITER=','; 
			
RUN;

































/* Gütemasse berechnen */

title j=center height=16pt color=black "Aktuelle Gütemasse";
data a;
  set m_fc.outstat;
  length typ $ 20;
  typ='Monatsprognose';
run;

data b;
  set w_fc.outstat;
  length typ $ 20;
  typ='Wochenprognose';
run;

data final;
  set a b;
run;

proc sort data=final;
  by typ artikel;
run;


PROC PRINT DATA=final noobs label 
   STYLE(HEADER)={BACKGROUND=lightgrey 
                  FOREGROUND=black 
                  FONT_SIZE=10pt
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=2pt}
   STYLE(DATA)={BACKGROUND=white
                  FOREGROUND=black 
                  FONT_SIZE=10pt
				  FONT_WEIGHT=LIGHT
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=0.5pt}
   STYLE(OBSHEADER)={BACKGROUND=lightgrey 
                  FOREGROUND=black 
                  FONT_SIZE=10pt
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=2pt}
	STYLE(OBS)={BACKGROUND=white
                  FOREGROUND=black 
                  FONT_SIZE=10pt
				  FONT_WEIGHT=LIGHT
                  CELLHEIGHT=14pt
                  BORDERCOLOR=BLACK
                  BORDERWIDTH=0.5pt}

;
   var artikel mape mse rmse;
   id typ;
   by typ;
   label Artikel ='Artikelnummer'
         mape='MAPE'
         mse='MSE'
         rmse='RMSE'
         typ='Prognosetyp';
RUN;



%stpend;





















