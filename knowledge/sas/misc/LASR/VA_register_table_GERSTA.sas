/* Festlegen der SAS Tabelle */
%let datatable=BRILLEN_DATENBANK;

/* LASR Tabelle registrieren */
LIBNAME VALIBLA SASIOLA  TAG=hps
	PORT=10010 SIGNER="http://gersta-2:80/SASLASRAuthorization"  HOST="gersta-2";

data VALIBLA.&datatable;
	set data.&datatable;
run;

proc metalib;
	omr ( library="Visual Analytics LASR" );
	select ( "&datatable" );
	folder = "/Products/SAS Visual Analytics Administrator";
run;

proc vasmp;
	serverinfo / port=10010 host="gersta-2";
	tableinfo / port=10010 host="gersta-2";
run;

/* LASR Tabellen löschen (Bei Bedarf scharf schalten!) */
proc datasets lib=VALIBLA;
	delete &datatable;
run;

proc metalib;
	omr ( library="Visual Analytics LASR" );
	select ( "BRILLEN_DATENBANK" );
	folder = "/Products/SAS Visual Analytics Administrator";
	UPDATE_RULE=(DELETE);
run;

proc vasmp;
	serverinfo / port=10010 host="gersta-2";
	tableinfo / port=10010 host="gersta-2";
run;