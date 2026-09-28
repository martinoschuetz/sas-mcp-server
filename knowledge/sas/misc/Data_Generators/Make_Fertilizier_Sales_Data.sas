data tmp;

 set data.telkodata;

 Demand=umsatz;
 Temp=marketing/10;

 length Region $30.;
 length Sku $40.;
 length Productline $40.;
 length Distribution $20.;
 if trim(channel)='Callcenter' then Region='Germany';
 else if trim(channel)='Eigene Shops' then Region='Canada';
 else if trim(channel)='Groﬂkunden' then Region='United States';
 else if trim(channel)='Home Shopping TV' then Region='Brazil';
 else if trim(channel)='Retail' then Region='Russia';
 else if trim(channel)='Vertragspartner' then Region='Australia';
 else if trim(channel)='Webseite' then Region='China';

 if trim(segment)='SOHO' then Distribution='Retail';
 else if trim(segment)='Business' then Distribution='Wholesale';
 else if trim(segment)='Consumer' then Distribution='Partners';

 if trim(tariftyp)='Clever & Smart' then Productline='Dr. Ben';
 else if trim(tariftyp)='Flatfone' then Productline='Dorian';
 else if trim(tariftyp)='Flexi' then Productline='Sinea';
 else if trim(tariftyp)='FunTalk' then Productline='Corvanto';
 else if trim(tariftyp)='PowerTalk' then Productline='Empex Blue';
 else if trim(tariftyp)='UMTS' then Productline='Phoenix';

 if trim(tarif)='Clever & Smart 120' then SKU='100234 A basic';
 else if trim(tarif)='Clever & Smart 30' then SKU='101781 A extended';
 else if trim (tarif)='Clever & Smart 60' then SKU='10300 A light';
 else if trim(tarif)='Flatfone Base' then SKU='218912 Medium';
 else if trim (tarif)='Flatfone Double' then SKU='228910 Forte';
 else if trim(tarif)='Flatfone Triple' then SKU='291011 Ultra';
 else if trim(tarif)='Flatfone Value' then SKU='291012 Ecoline';
 else if trim(tarif)='Flexi Basic' then SKU='30001 Red Line';
 else if trim(tarif)='Flexi Extra' then SKU='30002 Blue Line';
 else if trim(tarif)='Flexi Family&Friends' then SKU='30003 Silver Line';
 else if trim(tarif)='Flexi Happy Web' then SKU='30004 White Line'; 
 else if trim(tarif)='Flexi Professional' then SKU='30006 Green Line';
 else if trim(tarif)='Flexi Student' then SKU='30007 Mix';
 else if trim(tarif)='FunTalk 150' then SKU='512120 Alpha';
 else if trim(tarif)='FunTalk 25' then SKU='512121 Alpha +' ;
 else if trim(tarif)='FunTalk 50' then SKU='512200 Beta';
 else if trim(tarif)='PowerTalk 25' then SKU='6124011 Medium';
 else if trim(tarif)='PowerTalk 50' then SKU='6124010 Forte';
 else if trim(tarif)='UMTS Basic' then SKU='121012 Basic';
 else if trim(tarif)='UMTS Power' then SKU='121013 Extended'; 


 drop tarif tariftyp segment channel marketing planwerte umsatz;
 run;


 data data.FCS_Fertilizer;
  set tmp;
run;


