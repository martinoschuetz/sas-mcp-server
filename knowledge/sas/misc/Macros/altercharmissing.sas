%MACRO ALERTCHARMISSING(data=,vars=,alert=0.2);
	*** LOAD THE NUMBER OF ITENMS IN &VARS INTO MACRO VARIABLE NVARS;
	%LET C=1;

	%DO %WHILE(%SCAN(&vars,&c) NE);
		%LET C=%EVAL(&c+1);
	%END;

	%LET NVARS=%EVAL(&C-1);

	*** CALCULATE THE NUMBER OF OBSERVATIOSN IN THE DATASET;
	DATA _NULL_;
		CALL SYMPUT('N0',STRIP(PUT(nobs,8.)));
		STOP;
		SET &data NOBS=NOBS;
	RUN;

	PROC DELETE DATA = work._CharMissing_;
	RUN;

	%DO I = 1 %TO &NVARS;

		PROC FREQ DATA = &data(KEEP =%SCAN(&VARS,&I))  NOPRINT;
			TABLE %SCAN(&vars,&I) / MISSING OUT = DATA_%SCAN(&vars,&I)(WHERE =(%SCAN(&vars,&I) IS MISSING));
		RUN;

		DATA DATA_%SCAN(&vars,&i);
			FORMAT VAR $32.;
			SET data_%SCAN(&vars,&i);
			VAR = "%SCAN(&vars,&i)";
			DROP %SCAN(&vars,&i) PERCENT;
			RUN;

			PROC APPEND BASE = work._CharMissing_ DATA = DATA_%SCAN(&vars,&i) FORCE;
			RUN;

	%END;

	PROC PRINT DATA = work._CharMissing_;
	RUN;

	DATA _CharMissing_;
		SET _CharMissing_;
		FORMAT Proportion_Missing 8.2;
		N=&N0;
		Proportion_Missing = Count/N;
		Alert = (Proportion_Missing > &alert);
		RENAME var = Variable
			Count = NumberMissing;

		*IF _NAME_ = '_FREQ_' THEN DELETE;
	RUN;

	TITLE ALERTLIST FOR CATEGORICAL MISSING VALUES;
	TITLE2 DATA = &DATA -- ALERTLIMIT >= &ALERT;

	PROC PRINT DATA = _CharMissing_;
	RUN;

	TITLE;
	TITLE2;
%MEND;