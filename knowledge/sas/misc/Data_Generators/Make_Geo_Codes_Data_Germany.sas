/* Geocodierung von Postleitzahlen für Deutschland */

/* Hole Geocodes über http://fa-technik.adfc.de/code/opengeodb */

libname geo clear;
libname geo "C:\Sonstiges\SASCODE";

data geocodes;
 infile "C:\Sonstiges\SASCODE\PLZ.TXT" DELIMITER='09'x MISSOVER DSD;
 input
 Primaerschluessel : $5.
 PLZ : $5.
 Laengengrad : 8.
 Breitengrad : 8.
 Ort : $40.;
 run;


 proc sql; Create table GEOMAP as select
 a.x,
 a.y,
 a.long,
 a.lat,
 a.id,
 b._MAP_GEOMETRY_,
 b.IDNAME,
 b.ID2,
 b.STATE1,
 b.STATE2
 from maps.germany as a left join maps.germany2 as b on (a.ID=b.ID)
 order by a.ID,a.long;
 quit;


 data geo2;
  set geocodes;
   if lag(ort)=ort then delete;
run;

proc sql; create table geo3 as select
a.*,
b.laengengrad,
b.breitengrad,
b.ort,
b.plz,
a.state1,
a.state2
from geomap as a left join geo2 as b on (a.IDNAME=b.ort);
quit;
