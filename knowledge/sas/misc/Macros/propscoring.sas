%MACRO PropScoring(data=, out_ds=,vars=,library=sasuser,type=c);
	options fmtsearch = (&library work sasuser);
	%LET c=1;

	%DO %WHILE(%SCAN(&vars,&c) NE);
		%LET c=%EVAL(&c+1);
	%END;

	%LET nvars=%EVAL(&c-1);

	DATA &out_ds;
		SET &data;
		FORMAT

			%DO i = 1 %TO &nvars;
				%SCAN(&vars,&i)_m
			%END;
		16.3;;
		%DO i = 1 %TO &nvars;
			%IF &type = c %THEN

				IF UPCASE(%SCAN(&vars,&i)) = 'OTHER' then
					%SCAN(&vars,&i) = '_OTHER';;
				%SCAN(&vars,&i)_m = INPUT(PUT(%SCAN(&vars,&i),%SCAN(&vars,&i)f.),16.3);
		%END;
	RUN;

%MEND;