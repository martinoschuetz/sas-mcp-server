

/* Berechne Tagesreihe*/
data tagesreihe (Label='Tageskalendar von 2000 - 2020' drop=i);
do i=1 to 7671;
	tag='31DEC2006'd+i;
	format tag DATE9.;
	output;
end;

run;

data tagesreihe;
 set tagesreihe;
 if tag>'31DEC2013'd then delete;
 run;


/* Ferienkalender importieren (angelegte CSV -Datei )*/


DATA ferien;
    LENGTH
        bundesland       $ 22
        winter           $ 15
        ostern           $ 13
        pfingsten        $ 24
        sommer           $ 13
        herbst           $ 13
        weihnachten      $ 13
        jahr              4 ;
    LABEL
        bundesland       = "Bundesland"
        winter           = "Winter"
        ostern           = "Ostern"
        pfingsten        = "Pfingsten"
        sommer           = "Sommer"
        herbst           = "Herbst"
        weihnachten      = "Weihnachten"
        jahr             = "Jahr" ;
    FORMAT
        bundesland       $CHAR22.
        winter           $CHAR15.
        ostern           $CHAR13.
        pfingsten        $CHAR24.
        sommer           $CHAR13.
        herbst           $CHAR13.
        weihnachten      $CHAR13.
        jahr             BEST12. ;
    INFORMAT
        bundesland       $CHAR22.
        winter           $CHAR15.
        ostern           $CHAR13.
        pfingsten        $CHAR24.
        sommer           $CHAR13.
        herbst           $CHAR13.
        weihnachten      $CHAR13.
        jahr             BEST12. ;
    INFILE 'C:\DATEN\RWT\Schulferien.csv'
        LRECL=113
        ENCODING="WLATIN1"
        TERMSTR=CRLF
        DLM=';'
        MISSOVER
        DSD 
        firstobs=2;
    INPUT
        bundesland       : $CHAR22.
        winter           : $CHAR15.
        ostern           : $CHAR13.
        pfingsten        : $CHAR24.
        sommer           : $CHAR13.
        herbst           : $CHAR13.
        weihnachten      : $CHAR13.
        jahr             : BEST32. ;


		if trim(winter)='-' then winter='';
		if trim(pfingsten)='-' then pfingsten='';
		if index(pfingsten,'+')>0 or index(pfingsten,'/')>0 then do;
        rest=pfingsten;
        pfingsten='';
		end;
		



RUN;

proc print data=ferien(where=(rest ne ''));
 var bundesland rest jahr;
run;


PROC SORT
	DATA=WORK.FERIEN(KEEP=winter ostern pfingsten sommer herbst weihnachten bundesland jahr)
;	BY bundesland jahr;
RUN;


PROC TRANSPOSE DATA = WORK.FERIEN
	OUT=WORK.FERIEN_STACKED (drop=ferien1)
	PREFIX=Zeitraum
	NAME=Ferien1
	LABEL=Ferien;
	BY bundesland jahr;
	
	VAR winter ostern pfingsten sommer herbst weihnachten;
RUN;

data ferien_stacked;
 set ferien_stacked;
 where Ferien in ('Ostern', 'Sommer', 'Weihnachten', 'Winter', 'Herbst','Pfingsten');
 if trim(zeitraum1)='-' then zeitraum1='';


 dd1=substr(zeitraum1,1,2);
 mm1=substr(zeitraum1,4,2);
 dd2=substr(zeitraum1,8,2);
 mm2=substr(zeitraum1,11,2);

 nd1=input(dd1,2.0);
 md1=input(mm1,2.0);
 nd2=input(dd2,2.0);
 md2=input(mm2,2.0);
 y1=jahr;
 y2=jahr;
 if trim(ferien)='Weihnachten' and md2=1 then y2=y2+1;
 start_dt=mdy(md1,nd1,y1);
 end_dt=mdy(md2,nd2,y2);

 format start_dt end_dt date9.;

 if trim(bundesland)='Baden-Württemberg' then bundesland='BAW';
 else if trim(bundesland)='Bayern' then bundesland='BAY';
 else if trim(bundesland)='Berlin' then bundesland='BER';
 else if trim(bundesland)='Brandenburg' then bundesland='BRA';
 else if trim(bundesland)='Bremen' then bundesland='BRE';
 else if trim(bundesland)='Hamburg' then bundesland='HAM';
 else if trim(bundesland)='Hessen' then bundesland='HES';
 else if trim(bundesland)='Mecklenburg-Vorpommern' then bundesland='MVP';
 else if trim(bundesland)='Niedersachsen' then bundesland='NDS';
 else if trim(bundesland)='Nordrhein- Westfalen' then bundesland='NRW';
 else if trim(bundesland)='Rheinland-Pfalz' then bundesland='RLP';
 else if trim(bundesland)='Saarland' then bundesland='SLD';
 else if trim(bundesland)='Sachsen' then bundesland='SAX';
 else if trim(bundesland)='Sachsen-Anhalt' then bundesland='SAN';
 else if trim(bundesland)='Schleswig-Holstein' then bundesland='SLH';
 else if trim(bundesland)='Thüringen' then bundesland='THU';

 if trim(ferien)='Weihnachten' then ferien='WEI';
 else if trim(ferien)='Ostern' then ferien='OST';
 else if trim(ferien)='Sommer' then ferien='SOM';
 else if trim(ferien)='Winter' then ferien='WIN';
 else if trim(ferien)='Herbst' then ferien='HER';
 else if trim(ferien)='Pfingsten' then ferien='PFI';

 type=trim(bundesland)||'_'||trim(ferien);

 
 keep bundesland ferien start_dt end_dt type jahr;

 run;

 proc sort data=ferien_stacked; by bundesland;run;
data ferien_stacked;
 set ferien_stacked;
 retain bu_ind 0;
 if first.bundesland then bu_ind+1;
 by bundesland;
 if missing(end_dt) and not missing(start_dt) then end_dt=start_dt;
run;

%macro stack_buland;
  %do i=1 %to 16;

  data start&i;
    set ferien_stacked;
	where bu_ind=&i;
	bu&i=bundesland;
	start_dt&i=start_dt;
	end&i=end_dt;

	keep start_dt&i;
	format start_dt&i date9.;
   run;
   
   proc sort data=start&i;
    by start_dt&i;
    run;

   proc sql; create table merge1_&i as select
     a.tag,
     b.start_dt&i
   from tagesreihe as a left join start&i as b on
   a.tag=b.start_dt&i
   order by a.tag;
   quit;

   data ende&i;
    set ferien_stacked;
	where bu_ind=&i;
	bu&i=bundesland;
	end_dt&i=end_dt;
	
	keep end_dt&i;
	format end_dt&i date9.;
   run;
   
   proc sort data=ende&i;
    by end_dt&i;
    run;

   proc sql; create table merge2_&i as select
     a.tag,
	 a.start_dt&i,
     b.end_dt&i
   from merge1_&i as a left join ende&i as b on
   a.tag=b.end_dt&i
   order by a.tag;
   quit;

   data merge2_&i;
   set merge2_&i;
     retain status 0;
	 lag_stat=lag(status);
    if not missing (start_dt&i) then status=1;
	if not missing(end_dt&i) then status=0;

	 by tag;
   
	run;
   
   
   data merge2_&i;
   set merge2_&i;
	if not missing(end_dt&i) then status=1;
	ferien&i=status;
	keep tag ferien&i;
    
	run;
   

   %end;

%mend;
%stack_buland;

data rwt.holiday_calender;
 merge merge2_1 - merge2_16;
 by tag;

 baw=ferien1;
 bay=ferien2;
 ber=ferien3;
 bra=ferien4;
 bre=ferien5;
 ham=ferien6;
 hes=ferien7;
 mvp=ferien8;

 nds=ferien9;
 nrw=ferien10;
 rlp=ferien11;
 san=ferien12;
 sax=ferien13;
 sld=ferien14;
 slh=ferien15;
 thu=ferien16;

 drop ferien1-ferien16;

 /* Nachpflegen der nicht zusammenhängenden Pfingstferientage */
 if tag in ('18MAY2007'd,'29MAY2007'd,
            '02MAY2008'd,'13MAY2008'd,
            '22MAY2009'd,'02JUN2009'd,
			'14MAY2010'd,'25MAY2010'd,
            '03JUN2011'D,'14JUN2011'D,
            '30APR2012'D,'18MAY2012'D,'29MAY2012'D) then NDS=1;

 if tag in ('14MAY2010'd,'25MAY2010'd,
			'03JUN2011'd,'29JUN2011'd,
			'30APR2012'd,'18MAY2012'd) then BER=1;

 if tag in ('30APR2012'd,'18MAY2012'd) then BRA=1;

 if tag in ('18MAY2012'd,'08JUN2012'd) then RLP=1;

 if tag in ('03JUN2011'd,'18MAY2011'd) or 
    ('26APR2011'd<=tag<='29APR2011'd) or 
	('30APR2012'd<=tag<='04MAY2012'd) then HAM=1;


 /* gewichteter Index nach Bundesländer_bevölkerung*/
 ferienindex=
 0.131	*	BAW	+
 0.153	*	BAY	+
 0.042	*	BER	+
 0.031	*	BRA	+
 0.008	*	BRE	+
 0.022	*	HAM	+
 0.074	*	HES	+
 0.020	*	MVP	+
 0.097	*	NDS	+
 0.219	*	NRW	+
 0.049	*	RLP	+
 0.013	*	SLD	+
 0.051	*	SAX	+
 0.029	*	SAN	+
 0.035	*	SLH	+
 0.028	*	THU	
;

run;

proc datasets library=work nolist;
 delete start1-start16 ende1-ende16 merge1_1-merge1_16 merge2_1-merge2_16 ferien ferien_stacked


 /memtype=data;
run;
