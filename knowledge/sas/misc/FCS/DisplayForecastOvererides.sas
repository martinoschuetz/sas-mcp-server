data tmp;
 set results.finalfor;
 length comment $30.;
 if _reconstatus_=500 and month(datum) in (1,2,3) then comment='Winter-Aktionspreis';
 else if _reconstatus_=500 and month(datum) in (4,5,6) then comment='Fußball EM Spezial';
 else if _reconstatus_=500 and month(datum) in (7,8,9) then comment='Aktion: Scharfer Sommer';
 else if _reconstatus_=500 and month(datum) in (10,11,12) then comment='Aktion: Heißer Herbst';


 label datum='Kalenderwoche' predict='Endgültige Prognose' probfovr='Statistische Prognose';

 format datum weeku6.;


if _reconstatus_=0 then predict =.;

if lowbfovr<0 then lowbfovr=0;

uplift=(predict/prebfovr)-prebfovr;
format uplift percent8.2;

uplift2=put(uplift, $4.); 

run;

ods html file="C:\TEMP\Diagramm.html" style=journal gpath="C:\TEMP";
ods graphics on /width=700pt height=500pt imagemap=on border=off maxlegendarea=0 labelmax=400 outputfmt=gif;




title "Absatzmenge im Prognosezeitraum";


proc print data=_null_;
title "Absatzmenge im Prognosezeitraum";
run;

proc sgplot data=tmp (where=(trim(product)='FlopFlips light'));
    band x=datum upper=uppbfovr lower=lowbfovr /nooutline fillattrs=(COLOR=LIGHTGREY) transparency=0.2;
    series x=datum y=prebfovr 
     /  
        markers lineattrs=(COLOR=BLUE THICKNESS=2)
 		markerattrs=(SYMBOL=CIRCLEFILLED SIZE=10) 
        transparency=0.3;
  
   needle x=datum y=predict 
    / baseline=0
	  legendlabel='Korrekturwert'
      markers
	  markerattrs=(COLOR=RED SYMBOL=CIRCLE)
	  lineattrs=(COLOR=RED THICKNESS=4)
	  transparency=0.1
	  datalabel=comment DATALABELATTRS=(Color=RED Family=Arial Size=12 Style=Italic Weight=Normal);
	
    xaxis type=TIME tickvalueformat=weeku6. interval=WEEK display=all grid; 

	yaxis label='Absatzmenge in Stück';
run;

ods graphics off;

