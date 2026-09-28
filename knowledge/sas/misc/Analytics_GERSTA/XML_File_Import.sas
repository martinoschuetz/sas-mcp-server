filename NHL 'C:\My Documents\XML\NHL.xml';
filename MAP 'C:\My Documents\XML\NHL.map';
libname NHL xml xmlmap=MAP;

proc print data=NHL.TEAMS noobs; 
run;
