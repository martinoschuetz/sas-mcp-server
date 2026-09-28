/*----------------------------------------------------------------------------------------------------------*/
/*                                    BEISPIELCODE HIGH PERFORMANCE FORECASTING (HPF)                       */
/*                                    Vollständige Beschreibung der HPF Syntax unter:                       */
/*         http://support.sas.com/documentation/cdl/en/hpfug/62015/HTML/default/titlepage.htm               */
/*----------------------------------------------------------------------------------------------------------*/

/* Das Beispiel verwendet die mit SAS mitgelieferten Daten in SASHELP.PRICEDATA. Sie müssen im Code diese Angabe 
   global durch Ihre Datenquelle ersetzen */


/* Libref für Ausgabe der SAS-Tabellen mit Prognoseergebnissen*/
libname fcs_out "C:\TEMP";


/* Mit der Prozedur HPFARIMASPEC können Sie eigene ARIMA bzw. ARIMA-X Modelle spezifizieren, aber 
   auch einfache Modelle wie gleitende Durchschnitte, die sich mit der ARIMA-Methodologie abbilden lassen. 
   Sie können auch die Modelle interaktiv in Forecast Studio erstellen und den generierten SAS Code einfügen 
   anpassen. Für Modelle vom Typ Exponentielles Glätten existiert eine ähnliche Prozedur HPFESMSPEC. */

Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository /* Spezifizieren Sie einen SAS Katalog, in dem das Modell gespeichert werden soll*/
	SPECNAME=MA_WND_3 /* Unter diesem Namen wird das Modell später in der Modellliste referenziert */
	SPECLABEL="Moving Average (Smoothing window=3)"
	SPECTYPE=MOVEAVG
	SPECSOURCE=FSUI
	; 
FORECAST TRANSFORM = NONE
	NOINT  
	P = ( 1 2 3 )
	AR = ( 0.3333333333333333 0.3333333333333333 0.3333333333333333 ) ; 
ESTIMATE NOEST NOSTABLE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;


Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=MA_WND_4
	SPECLABEL="Moving Average (Smoothing window=4)"
	SPECTYPE=MOVEAVG
	SPECSOURCE=FSUI
	; 
FORECAST TRANSFORM = NONE
	NOINT  
	P = ( 1 2 3 4)
	AR = ( 0.25 0.25 0.25 0.25) ; 
ESTIMATE NOEST NOSTABLE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;


Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=MA_WND_5
	SPECLABEL="Moving Average (Smoothing window=5)"
	SPECTYPE=MOVEAVG
	SPECSOURCE=FSUI
	; 
FORECAST TRANSFORM = NONE
	NOINT  
	P = ( 1 2 3 4 5)
	AR = ( 0.2 0.2 0.2 0.2 0.2) ; 
ESTIMATE NOEST NOSTABLE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=MA_WND_6
	SPECLABEL="Moving Average (smoothing window=6)"
	SPECTYPE=MOVEAVG
	
	; 
FORECAST SYMBOL = Y TRANSFORM = NONE
	NOINT  
	P = ( 1 2 3 4 5 6 )
	AR = ( 0.16666666666666666 0.16666666666666666 0.16666666666666666 0.16666666666666666 0.16666666666666666 0.16666666666666666 ) ; 
ESTIMATE NOEST NOSTABLE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;



Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=RANDOMWALK
	SPECLABEL="Random Walk"
	SPECTYPE=RANDWALK

	; 
FORECAST SYMBOL = Y TRANSFORM = NONE
	NOINT 
	DIF = ( 1 )  ; 
ESTIMATE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;


Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=RANDOMWALKSEASONAL
	SPECLABEL="Random Walk (Seasonal)"
	SPECTYPE=RANDWALK

	; 
FORECAST SYMBOL = Y TRANSFORM = NONE
	NOINT 
	DIF = ( 1 s )  ; 
ESTIMATE 
	METHOD=CLS 
	CONVERGE=0.0010 
	MAXITER=50 
	DELTA=0.0010 
	SINGULAR=1.0E-7  ; 
run;

Proc HPFARIMASPEC
	MODELREPOSITORY = fcs_out.repository
	SPECNAME=AVERAGE
	SPECLABEL="Mean"
	SPECTYPE=ARIMA
	; 
FORECAST SYMBOL = Y TRANSFORM = NONE  ; 
ESTIMATE 
	METHOD=ML 
	CONVERGE=1.0E-4 
	MAXITER=150 
	DELTA=1.0E-4 
	SINGULAR=1.0E-7  ; 
run;


/* Mit der Prozedur HPFSELECT werden die zuvor generierten Modelle in einer Liste zusammengestellt. 
   Diese Liste kann später mit HPFDIAGNOSE (oder HPFENGINE) verwendet werden. */

Proc HPFSELECT
	MODELREPOSITORY = fcs_out.repository /* Verweis auf den Modell-Katalog */
	SELECTNAME=NAIVE /* Unter diesem Namen wird die Modellliste von HPFDIAGNOSE (oder HPFENGINE) referenziert*/
	SELECTLABEL="Naive Models"
	; 

	/* Sie können die Kriterien für Holdout-Sample und Prognosefehlermaß zur Modellwahl hier festlegen */
	SELECT
		HOLDOUT=0
		HOLDOUTPCT=100.0
		CRITERION=MAE;
	/* Jeder der SPEC-Statement verweist auf ein zuvor generiertes Modell */ 
	SPEC RANDOMWALK ;
	SPEC RANDOMWALKSEASONAL;
	SPEC AVERAGE;
    SPEC MA_WND_6;
    SPEC MA_WND_5;
    SPEC MA_WND_4;
    SPEC MA_WND_3;
 
run;





/* Diese Prozedur führt die Diagnose für die automatisch system-seitig generierten Modell durch */
proc hpfdiagnose data=sashelp.pricedata /*Hier müssen Sie auf die richtige Datentabelle verweisen*/
                    repository=fcs_out.repository  /* In diesem Repository (SAS Katalog) werden die diagnostizierten Modelle gespeichert. 
					                                  In diesem Fall werden sie mit den Modellen aus der eigenen Modellliste kombiniert */
                    outest=fcs_out.est /* In dieser Tabelle werden die vorläufigen Modellparameter aus dem Diagnoseschritt gespeichert*/
					alpha=0.05 /* Legt Breite des Konfidenzintervalls fest: 0.05 bedeutet 95% */
					criterion=MAE /* Kriterium für Modellauswahl, in Ihrem Fall zunächst SBC */
					holdout=12/* Anzahl Perioden für Holdout-Sample (möchten Sie kein Holdout, geben Sie 0 an !*/
					inselectname=NAIVE /* mit PROC HPFSELECT erstellte Liste mit benutzerdefinierten (naiven) Modellen. 
					                      Falls Sie nur automatische Diagnostik verwenden möchte, bitte dieses Statement auskommentieren */
;
transform type=AUTO; /* Hier legen Sie fest, ob automatisch Transformation geprüft wird (ohne: TYPE=NONE)*/
arimax outlier=(detect=YES maxnum=5); /* System-seitig generierte ARIMA-Modelle, Setzen Sie DETECT=NO, wenn keine Ausreißer erkannt werden sollen*/
esm; /* System-seitig generiete Modelle vom Typ Exponentielles Glätten */
/*ucm */ /* System-seitig generierte Unobserved Components Modelle */


input price discount; /* Hier legen Sie die Namen der Input-Variable(n) fest, es können mehr als eine sein */
id date interval=month; /* Hier müssen Sie Variable und Zeitintervall für Zeitstempel festlegen */
forecast sale; /* Hier legen Sie die zu prognostizierende Variable fest */
by regionname productline productname; /* Hier legen Sie die By-Groups fest */
run;


/* Diese Prozedur führt die eigentliche Prognose durch */ 
 proc hpfengine data=sashelp.pricedata
                  repository=fcs_out.repository /* Hier muss das kombinierte Repository stehen */
                  inest=fcs_out.est /* Hier muss auf die Tabelle mit den vorläufigen Parameterschätzern verwiesen werden */
				  
		
                  lead=12 /* Anzahl der Perioden, die in die Zukunft prognostiziert werden soll */

				  /* Hier spezifizieren Sie, wohin die diversen Ausgabetabellen geschrieben werden sollen */
				  out=_NULL_
                  outest=fcs_out.outest
				  outfor=fcs_out.outfor
				  outstat=fcs_out.outstat
				  outstatselect=fcs_out.outstatselect
				  outmodelinfo=fcs_out.outmodelinfo
              
                  ;


/* Dieser Abschnitt sollte identisch sein zu dem in HPFDIAGNOSE */
input price discount; 
id date interval=month;
forecast sale;
by regionname productline productname;
run;
