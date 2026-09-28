%MACRO TARGETCHART(data=,target=,interval=,class=);

	PROC SQL NOPRINT;
		SELECT AVG(&Target) INTO :_Mean FROM &data;
	QUIT;

	PROC GCHART DATA=&data;
		%IF &class ne %THEN;
			HBAR &class /TYPE=MEAN FREQ DISCRETE MISSING SUMVAR=&target SUM MEAN REF=&_mean;

			%IF &interval ne %THEN;
				HBAR &interval/type=MEAN FREQ MISSING SUMVAR=&target SUM MEAN REF=&_mean;
	RUN;

	QUIT;

%MEND;

%targetchart(data=&EM_IMPORT_DATA,target=%EM_TARGET,interval=%EM_INTERVAL,class=%EM_CLASS)
