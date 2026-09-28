
data sashelp.snacks2;
   set sashelp.snacks;
   if product = "Baked potato chips" then product = "Crunchy Sticks Classic";
   else if product = "Barbeque pork rinds" then product = "Crunchy Sticks Light";
   else if product = "Barbeque potato chips" then product = "Crunchy Sticks Edel";
   else if product = "Bread sticks" then product = "Crunchy Sticks Würzig";
 else if product = "Buttery popcorn" then product = "Crunchy Sticks 50% Fat";
 else if product = "Carmelized popcorn" then product = "SASletten normal";
 else if product = "Cheddar cheese break sticks" then product = "SASletten Paprika";
 else if product = "Cheddar cheese popcorn" then product = "SASletten extra salzig ";
 else if product = "Cheese puffs" then product = "SASletten Fiesta Mexicana";
 else if product = "Classic potato chips" then product = "SASletten Feurig";
 else if product = "Easy dip tortilla chips" then product = "SASletten Mild";
 else if product = "Extra hot pork rinds" then product = "SASletten Party";
 else if product = "Fiesta sticks" then product = "FlopFlips klassisch";
 else if product = "Fried pork rinds" then product = "FlopFlips light";
 else if product = "Hot spicy cheese puffs" then product = "FlopFlips herzhaft";
 else if product = "Jalepeno sticks" then product = "FlopFlips exotisch";
 else if product = "Jumbo pretzel sticks" then product = "SAS Riegel Vollmilch";
 else if product = "Low-fat popcorn" then product = "SAS Riegel Erdbeer/Joghurt";
 else if product = "Low-fat saltines" then product = "SAS Riegel Vanille";
 else if product = "Multigrain chips" then product = "SAS Riegel Nuss";
 else if product = "Pepper sticks" then product = "SAS Riegel Zartbitter";
 else if product = "Pretzel sticks" then product = "SAS Riegel Beste Auswahl";
 else if product = "Pretzel twists" then product = "SAS Bonbons Fun";
 else if product = "Ruffled potato chips" then product = "SAS Bonbons Best Selection";
 else if product = "Rye crackers" then product = "SAS Bonbons - Alle Neune ";
 else if product = "Salt and vinegar potato chips" then product = "Candyland Fun";
 else if product = "Saltine crackers" then product = "Candyland Action";
 else if product = "Shredded wheat crackers" then product = "Candyland Paradise";
 else if product = "Stone-ground wheat sticks" then product = "Candyland Super";
 else if product = "Sun-dried tomato multigrain chips" then product = "SAS Slim - Normal";
 else if product = "Tortilla chips" then product = "SAS Slim - Sport";
 else if product = "WOW cheese puffs" then product = "SAS Slim - Diät";
 else if product = "WOW potato chips" then product = "SAS Slim - Extra";
 else if product = "WOW tortilla chips" then product = "SAS Slim - Zuckerfrei";
 else if product = "Wheat crackers" then product = "SAS Vielfalt";
 date=date+730;
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
 label product="Produkt" price="VK-Preis" date="Datum" qtysold="Abverkaufsmenge" 
       productgroup="Produktgruppe" category="Produktkategorie";


run;

%include "D:\DataSave\mywork\sasprog\create_events_calender.sas";

data fc.eventkalender;
  set work.temp4;
  where tag>='01Jan2004'd and tag<'01Jan2008'd;
  keep 
run;

proc sql;
  create table sashelp.snacks3 as select
    snacks2.date as date,
	snacks2.qtysold as qtysold,
	snacks2.price as price,
	snacks2.product as product,
	snacks2.productgroup as productgroup,
	snacks2.category as category,
	temp4.event as event,
	temp4.flag1 as flag1,
	temp4.flag2 as flag2,
	temp4.flag3 as flag3,
	temp4.wochentag as wochentag,
	temp4.wochentag2 as wochentag2
	from sashelp.snacks2, work.temp4

    where snacks2.date=temp4.tag
    order by category, productgroup, product, date;
quit;

data sashelp.snacks3;
  set sashelp.snacks3;
  if flag1=1 or flag2=1 or wochentag=1 then qtysold=0;
run;

proc expand data=sashelp.snacks3 out=sashelp.snacks4 from=day to=month; 
        convert qtysold / observed=total; 
	    convert price / observed=beginning;
         id date;
	     by category productgroup product;
       run; 


data sashelp.snacks4;
  set sashelp.snacks4;
  length camptext $ 30;
  qtysold=int(qtysold);
  if missing(qtysold) then delete;
  if productgroup ="SASletten" and date in('01SEP2004'd,'01May2005'd) then campaign=1;
  else if product ='SAS Slim - Diät' and date in ('01Jun2006'd) then campaign=2;
  else if product ="SAS Vielfalt" and date in ('01Nov2004'd,'01Oct2005'd,'01Sep2006'd) then campaign=3;

  if campaign=1 then camptext='SASletten Funkspot';
  else if campaign=2 then camptext='Slim TV Sommerkampagne';
  else if campaign=3 then camptext='TV-Spot - Die Vielfalt ist wieder da!';
  if campaign=1 and qtysold>0 then qtysold=int(qtysold*2);
  else if campaign=2 and qtysold>0 then qtysold=int(qtysold*4);
  else if campaign=3 and qtysold>0 then qtysold=int(qtysold*2);
  label camptext='Werbekampagne - Info' campaign='Werbekampagne';

  if campaign>0 then campaign=1; else campaign=0; 
run;

libname fc "D:\DATEN\FORECAST";

  data fc.snacks4;
    set sashelp.snacks4;
run;
