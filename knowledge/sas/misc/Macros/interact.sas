%MACRO interact(vars, quadr = 1, prefix = INT);
	*** Load the number of itenms in &VARS into macro variable NVARS;
	%LET c=1;

	%DO %WHILE(%SCAN(&vars,&c) NE);
		%LET c=%EVAL(&c+1);
	%END;

	%LET nvars=%EVAL(&c-1);

	%DO i = 1 %TO &nvars;
		%DO j = %EVAL(&i+1-&quadr) %TO &nvars;
			&prefix._%SCAN(&vars,&i)_%SCAN(&vars,&j) = 
				%SCAN(&vars,&i) * %SCAN(&vars,&j);
		%END;
	%END;
%MEND;