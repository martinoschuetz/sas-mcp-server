%MACRO makelong_ds(DATA=,OUT=,COPY=,ID=,LIST=,MAX=,MIN=,
			ROOT=,TIME=Measurement);

	DATA &out(WHERE = (&root NE .));
		SET &data;

		%IF &list NE %THEN
			%DO;
				*** run the macro in LIST-Mode;
				*** Load the number of itenms in &VARS into macro variable NVARS;
				%LET c=1;

				%DO %WHILE(%SCAN(&list,&c) NE);
					%LET c=%EVAL(&c+1);
				%END;

				%LET nvars=%EVAL(&c-1);

				%DO i = 1 %TO &nvars;
					&root=&root.%SCAN(&list,&i);
					&time = %SCAN(&list,&i);
					OUTPUT;
				%END;
			%END;
		%ELSE
			%DO;
				*** run the macro in FROM/TO mode;
				%DO i = &min %TO &max;
					&root=&root.&i;
					&time= &i;
					OUTPUT;
				%END;
			%END;

		KEEP &id &copy &root &time;
	RUN;

%MEND;