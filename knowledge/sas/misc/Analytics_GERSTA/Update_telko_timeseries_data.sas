
proc sort data=fcslib.telkodata out=temp;
by segment channel tariftyp tarif zeitstempel;run;

data temp;
 set temp;
 if first.tarif then x=1;
 by segment channel tariftyp tarif;
 if x=1;
 zeitstempel=mdy(1,1,2009);
 umsatz=.;
 preisindex=.;
 planwerte=.;
 marketing=.;
 drop x;

run;

proc sort data=fcslib.telkodata out=temp2;
 by segment channel tariftyp tarif zeitstempel;
 run;


 data temp3;
   merge temp2 temp;
   by segment channel tariftyp tarif zeitstempel;

run;

data temp4;
 set temp3;
 lagums=lag12(umsatz);
 lagmarketing=lag(marketing);
 lagpreis=lag(preisindex);
 lagplan=lag(planwerte);
run;

data temp5;
 set temp4; 
   if zeitstempel in ('01DEC2007'd) then umsatz=int(lagums*(1+rannor(3242)/50));
   if missing(marketing) then do;
     marketing=int(lagmarketing*(1+rannor(32)/10));
	 preisindex=lagpreis*(1+rannor(324)/20);
	 planwerte=int(lagplan*(1+rannor(357)/20));
   end;
   drop lagmarketing lagums lagpreis lagplan;
run;

data fcslib.telkodata2;
 set temp5;
run;