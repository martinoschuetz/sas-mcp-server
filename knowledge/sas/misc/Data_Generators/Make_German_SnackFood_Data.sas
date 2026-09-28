libname fc "D:\DATEN\FORECAST";

data fc.pricedata (rename=(product=prodalt));
  set sashelp.pricedata;

  
run;

data temp1;
   set fc.pricedata;
   length product $30;
   if productname = "Product1" then product = "Crunchy Sticks Classic";
   else if productname = "Product2" then product = "Crunchy Sticks Light";
   else if productname = "Product3" then product = "Crunchy Sticks Edel";
   else if productname = "Product4" then product = "Crunchy Sticks Würzig";
 else if productname = "Product5" then product = "Crunchy Sticks 50% Fat";
 else if productname = "Product6" then product = "SASletten normal";
 else if productname = "Product7" then product = "SASletten Paprika";
 else if productname = "Product8" then product = "SASletten extra salzig ";
 else if productname = "Product9" then product = "SASletten Fiesta Mexicana";
 else if productname = "Product10" then product = "SASletten Feurig";
 else if productname = "Product11" then product = "SASletten Mild";
 else if productname = "Product12" then product = "SASletten Party";
 else if productname = "Product13" then product = "FlopFlips klassisch";
 else if productname = "Product14" then product = "FlopFlips light";
 else if productname = "Product15" then product = "FlopFlips herzhaft";
 else if productname = "Product16" then product = "FlopFlips exotisch";
 else if productname = "Product17" then product = "SAS Vielfalt";
 
 label sale='Abverkauf' date='Monat' product='Produkt';
 drop productname;

  format date monyy7.;
run;

data temp2;
 set fc.pricedata;
 length product $30;
   
 sale=sale+int(ranuni(1)*50);
  if productname = "Product1" then product = "SAS Riegel Vollmilch";
   else if productname = "Product2" then product = "SAS Riegel Erdbeer/Joghurt";
   else if productname = "Product3" then product = "SAS Riegel Vanille";
   else if productname = "Product4" then product = "SAS Riegel Zartbitter";
 else if productname = "Product5" then product = "SAS Riegel Beste Auswahl";
 else if productname = "Product6" then product = "SAS Bonbons - Herzhaft";
 else if productname = "Product7" then product = "SAS Bonbons - Best Selection";
 else if productname = "Product8" then product = "SAS Bonbons - Alle Neune";
 else if productname = "Product9" then product = "Candyland Fun";
 else if productname = "Product10" then product = "Candyland Action";
 else if productname = "Product11" then product = "Candyland Paradise";
 else if productname = "Product12" then product = "Candyland Super";
 else if productname = "Product13" then product = "SAS Slim - Normal";
 else if productname = "Product14" then product = "SAS Slim - Sport";
 else if productname = "Product15" then product = "SAS Slim - Diät";
 else if productname = "Product16" then product = "SAS Slim - Extra";
 else if productname = "Product17" then product = "SAS Slim - Zuckerfrei";
 label sale='Abverkauf' date='Monat' product='Produkt';
 drop productname;

  format date monyy7.;
run;

data temp3;
  set temp1 temp2;
  if find(product,"Crunchy Sticks",1)=1 then productgroup="Crunchy Sticks";
 else if find(product,"SASletten",1)=1 then productgroup="SASletten";
 else if find(product,"FlopFlips",1)=1 then productgroup="FlopFlips";
 else if find(product,"SAS Riegel",1)=1 then productgroup="SAS Riegel";
 else if find(product,"SAS Bonbons",1)=1 then productgroup="SAS Bonbons";
 else if find(product,"Candyland",1)=1 then productgroup="Candyland";
 else if find(product,"SAS Slim",1)=1 then productgroup="SAS Slim";
 else if find(product,"SAS Vielfalt",1)=1 then productgroup="SAS Vielfalt";
 if productgroup in ("Crunchy Sticks", "SASletten", "FlopFlips") then category="Salzgebäck";
 else category="Süssgebäck";
 label product="Produkt" date="Monat" 
       productgroup="Produktgruppe" category="Produktkategorie";

 sale=sale*1000+round(ranuni(1)*1000,50);
 format sale commax20.;
 TAG=1;
 Jahr=year(date)+4;
 Monat=month(date);
 date=mdy(monat,tag,jahr);
 format date monyy7.;
 drop prodalt monat tag jahr;
 if date>'01Oct2006'd then delete;
run;


data fc.sasfoods;
  set temp3;
  length camptext $ 40;
  
  if productgroup ="SASletten" and date in('01SEP2004'd,'01May2005'd) then campaign=1;
  else if product ='SAS Slim - Diät' and date in ('01Jun2006'd) then campaign=2;
  else if product ="SAS Vielfalt" and date in ('01Nov2004'd,'01Oct2005'd,'01Sep2006'd) then campaign=3;

  if campaign=1 then camptext='SASletten Funkspot';
  else if campaign=2 then camptext='Slim TV Sommerkampagne';
  else if campaign=3 then camptext='TV-Spot - Die Vielfalt ist wieder da!';
  if campaign=1 and sale>0 then sale=int(sale*1.2);
  else if campaign=2 and sale>0 then sale=int(sale*1.5);
  else if campaign=3 and sale>0 then sale=int(sale*1.2);
  label camptext='Werbekampagne - Info' campaign='Werbekampagne';
  drop regionname productline price price1--price17 discount cost region line;
  if campaign>0 then campaign=1; else campaign=0; 
  
run;
