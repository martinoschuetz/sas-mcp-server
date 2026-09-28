/*
	Beispielprogramm Konversion von Latin1 in UTF8;
	Ab hier immer mit SAS Session im Zielencoding laufen lassen. 
    -für Konversion latin1=>UTF8: das Programm mit sas-UTF8 Session laufen lassen
    -für Konversion UTF8=>Latin1: das Programm mit sas-Latin1 Session laufen lassen;

	Beispielprogramm Konversion von Latin1 in UTF8. Dies Programm muss also mit einer UTF8 SAS Szession laufen um richtige Ergebnisse zu liefern!!!!;
*/
LIBNAME source CVP "c:\temp\source" INENCODING=LATIN1 EOC=NO;*CVP ist wichtig um die Variablenlängen anzupassen: zB.                                                                                                                    das Zeichen „Ü“ hat Länge 2 in UTF8 und 1 in Latin1;
LIBNAME target BASE "c:\temp\Target" OUTENCODING=UTF8 EOC=NO;

proc datasets library=source;
   copy out=target noclone; *NOCLONE ist wichtig sonst bleibt alles beim alten Encoding;
run;quit;
