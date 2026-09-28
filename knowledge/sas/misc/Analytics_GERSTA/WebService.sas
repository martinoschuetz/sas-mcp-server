
FILENAME Response "C:\TEMP\Response1.xml";
PROC HTTP URL =
'http://api.geonames.org/findNearbyPlaceName?lat=42&lng=42&username=demo'
OUT = Response
METHOD = 'GET';
/*
proxyhost="srv01gr.unx.sas.com"
proxyport=8118;
*/
RUN;

libname myxml xml 'C:\TEMP\Response1.xml';


data geoname;
set myxml.geoname;
run;
proc print data = geoname noobs;
run;