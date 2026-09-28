CAS mySession SESSOPTS=(CASLIB=public TIMEOUT=999 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;

/* Drop in-memory CAS table  */
proc casutil;
	droptable casdata="&gateuserid._CSV_prdsale" incaslib="DM" quiet;
quit;
	
CAS mySession TERMINATE;