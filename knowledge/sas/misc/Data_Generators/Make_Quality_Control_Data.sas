libname opel "C:\Opel";

data opel.qcdata (drop=i x1 x2 x3);
   do i=1 to 2700;
   abtastzeit='01NOV2004'd+i/10;
   zielgroesse=100+rannor(1)*5;
   prozessvar1=rannor(1)*100+200;
   prozessvar2=abtastzeit+rannor(1)*10;
   prozessvar3=rannor(1)*100+200;
   prozessvar4=rannor(1)*100+300;
   prozessvar5=rannor(1)*100+200;
   prozessvar6=rannor(1)*100+200;
   prozessvar7=rannor(1)*100+230;
   prozessvar8=rannor(1)*100+210;
   prozessvar9=rannor(1)*100+210;
   prozessvar10=rannor(1)*100+200;
   x1=ranuni(1)*100;
   x2=ranuni(1)*100;
   x3=ranuni(1)*100;
   if x1<30 then maschine='Band 1';
   else if x1<70 then maschine='Band 2';
   else maschine='Band 3';
   if x2<20 then pruefer='Prüfer A';
   else if x2<40 then pruefer='Prüfer B';
   else if x2<60 then pruefer='Prüfer C';
   else if x2<80 then pruefer='Prüfer D';
   else pruefer='Prüfer E';
   if x3>60 then werk='Werk A';
   else werk='Werk B';
   if pruefer ='Prüfer A' and maschine='Band 1' then zielgroesse=zielgroesse-20;
   else if prozessvar9>120 and werk='Werk B' then zielgroesse=zielgroesse-70;

   output;
   end;
   
   format abtastzeit date9. zielgroesse prozessvar1--prozessvar10 8.2;
   label abtastzeit='Abtastzeit'
         zielgroesse='Zielgröße'
         prozessvar1='Prozessvariable 1'
         prozessvar2='Prozessvariable 2'
         prozessvar3='Prozessvariable 3'
		 prozessvar4='Prozessvariable 4'
		 prozessvar5='Prozessvariable 5'
		 prozessvar6='Prozessvariable 6'
         prozessvar7='Prozessvariable 7'
         prozessvar8='Prozessvariable 8'
         prozessvar9='Prozessvariable 9'
         prozessvar10='Prozessvariable 10'
         maschine='Fertigungsband'
		 pruefer='Prüfer Endkontrolle'
		 werk='Produktionswerk'
;

run;
