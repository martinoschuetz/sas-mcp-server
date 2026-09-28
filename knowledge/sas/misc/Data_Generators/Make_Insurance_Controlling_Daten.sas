libname fcslib "D:\DATEN\QUELLEN";

data tmp;
 set fcslib.insurance (rename=(produktgruppe=sparte));

 if zeitstempel='01FEB06'D and region='Bayern' and bezirksdirektion='Bayreuth' and sparte='Haftpflicht' and tariftyp='Bauherrenhaftpflicht'
 then neuvertragsvolumen=5566;

 drop rel_preis werbebudget kampagne neuvertragsvolumen;
 neuvertraege=neuvertragsvolumen;
 gesamtvolumen=(20+int(ranuni(4324)*4))*neuvertraege;
 schadenaufw=0.5+(ranuni(4324)/10)*gesamtvolumen;


 format gesamtvolumen neuvertraege schadenaufw commax12.0
; 
 run;


 proc sql; create table tmp2 as select
 distinct sparte,
          region,
		  bezirksdirektion,
		  zeitstempel,
		  sum(gesamtvolumen) as umsatz_gesamt format commax12.0 label='Gesamtumsatz',
          (0.54+ranuni(32)/10)*sum(gesamtvolumen) as kosten_sparte format commax12.0 label='Fixkosten Vertrieb pro Sparte'
		  

  from tmp 
  group by sparte, region, bezirksdirektion, zeitstempel;quit;

  proc sql; create table tmp3 as select
  a.*,
  b.kosten_sparte,
  b.umsatz_gesamt format comma12.0
  from tmp as a left join tmp2 as b on a.region=b.region and a.bezirksdirektion=b.bezirksdirektion and a.sparte=b.sparte 
                               and a.zeitstempel=b.zeitstempel
  order by region, bezirksdirektion, sparte, tariftyp, zeitstempel;quit;



  
 proc sql; create table tmp4 as select
 distinct tariftyp,
          sparte,       
          region,
		  bezirksdirektion,
		  zeitstempel,
		  sum(gesamtvolumen) as totalx format commax12.0,		  
          (0.6+ranuni(33)/10)*sum(gesamtvolumen) as kosten_tariftyp format commax12.0 label='Fixkosten Vertrieb pro Tariftyp'
		  

  from tmp 
  group by tariftyp, sparte, region, bezirksdirektion, zeitstempel;quit;

  proc sql; create table tmp5 as select
  a.*,
  b.kosten_tariftyp
  from tmp3 as a left join tmp4 as b on a.region=b.region and a.bezirksdirektion=b.bezirksdirektion and a.sparte=b.sparte and a.tariftyp=b.tariftyp and a.zeitstempel=b.zeitstempel
  order by region, bezirksdirektion, sparte, tariftyp, zeitstempel;quit;


  data tmp6;
   set tmp5;
   db1=umsatz_gesamt-kosten_sparte;
   db2=db1-kosten_tariftyp;
   format db1 db2 commax12.0;
   if missing(neuvertraege) then delete;

   zeitstempel=zeitstempel+366+50;


run;

data fcslib.insurance2;
 set tmp6;

 neuvertraege=(neuvertraege*2)*(1+ranuni(3324)/10);
 gesamtvolumen=(gesamtvolumen)*(1+rannor(4324)/10);
 deckungsbeitrag1=(gesamtvolumen)*(0.3+rannor(444)/200);
 deckungsbeitrag2=(gesamtvolumen)*(0.14+rannor(555)/200);
 schadenaufw=schadenaufw;
 kosten_sparte=(kosten_sparte)*(1+ranuni(400)/10);
 kosten_tariftyp=(kosten_tariftyp)*(1+ranuni(500)/10);


 if bezirksdirektion in ('Bayreuth', 'Würzburg', 'Lübeck', 'Magdeburg') then f1=0.73; else f1=1;
 if tariftyp in ('Motorrad','Roller/Moped', 'Bauherrenhaftplicht') then f2=0.67; else f2=1;

 f3=1+rannor(4324)/20;

 zielerreichung=f3*f2*f1;
 length zielbinaer $12.0;
 if zielerreichung<0.95 then zielbinaer='Über Plan'; else zielbinaer='Unter Plan';
 
 if ranuni(4234)<0.005 then do;
    neuvertraege=neuvertraege*2;
    schadenaufw=schadenaufw/5;
	deckungsbeitrag1=deckungsbeitrag1*5;
	deckungsbeitrag2=deckungsbeitrag2*4;

 end;

 label 
       zeitstempel='Berichtsmonat'
	   region='Vertriebsregion'
	   bezirksdirektion='Bezirksdirektion'
       gesamtvolumen='Bruttobeitragseinnahmen gesamt'
       neuvertraege='Neuvertragsvolumen'
       schadenaufw='Schadenaufwendungen'
	   sparte='Sparte'
	   zielerreichung='Zielerreichung in %'
	   zielbinaer='Zielerreichung'
	   deckungsbeitrag1='DB I (vor Spartenfixkosten)'
	   deckungsbeitrag2='DB II (vor Tariffixkosten)'
       ;


format neuvertraege gesamtvolumen deckungsbeitrag1 deckungsbeitrag2 schadenaufw kosten_sparte kosten_tariftyp commax12.0
       zielerreichung 8.2;

drop umsatz_gesamt f1 f2 f3 db1 db2;
 run;