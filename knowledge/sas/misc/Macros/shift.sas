%MACRO SHIFT (OPERATION,VAR,VALUE, MISSING=PRESERVE);
	%IF %UPCASE(&missing) = PRESERVE %THEN
		%DO;
			IF &var NE . THEN
				&var = &operation(&var,&value);
		%END;
	%ELSE %IF %UPCASE(&missing) = REPLACE %THEN
		%DO;
			&var = &operation(&var,&value);
		%END;
%MEND;