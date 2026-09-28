%MACRO RememberCategories(data =, vars=,lib=sasuser);
	*** Load the number of itenms in &VARS into macro variable NVARS;
	%LET c=1;

	%DO %WHILE(%SCAN(&vars,&c) NE);
		%LET c=%EVAL(&c+1);
	%END;

	%LET nvars=%EVAL(&c-1);

	%DO i = 1 %TO &nvars;

		PROC FREQ DATA = &data NOPRINT;
			TABLE %SCAN(&vars,&i) / MISSING OUT = &lib..cat_%SCAN(&vars,&i)(DROP = COUNT PERCENT);
		RUN;

	%END;
%MEND;