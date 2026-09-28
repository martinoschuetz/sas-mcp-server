%MACRO CheckCategories(scoreds=, vars=,lib=sasuser);
	*** Load the number of itenms in &VARS into macro variable NVARS;
	%LET c=1;

	%DO %WHILE(%SCAN(&vars,&c) NE);
		%LET c=%EVAL(&c+1);
	%END;

	%LET nvars=%EVAL(&c-1);

	%DO i = 1 %TO &nvars;

		PROC FREQ DATA = &scoreds NOPRINT;
			TABLE %SCAN(&vars,&i) / MISSING OUT = &lib..score_%SCAN(&vars,&i)(DROP = COUNT PERCENT);
		RUN;

		PROC SQL;
			CREATE TABLE &lib..NEW_%SCAN(&vars,&i)
				AS
					SELECT %SCAN(&vars,&i)
						FROM &lib..score_%SCAN(&vars,&i)
							EXCEPT
						SELECT %SCAN(&vars,&i)
							FROM &lib..cat_%SCAN(&vars,&i)
			;
		QUIT;

		TITLE New Categories found for variable %SCAN(&vars,&i);

		PROC PRINT DATA = &lib..NEW_%SCAN(&vars,&i);
		RUN;

		TITLE;
	%END;
%MEND;