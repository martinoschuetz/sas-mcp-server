%MACRO FILTER (VAR,OPERATION,VALUE, MISSING=PRESERVE);
	%IF %UPCASE(&missing) = PRESERVE %THEN
		%DO;
			IF &var NE . AND &var &operation &value THEN
				DELETE;
		%END;
	%ELSE %IF %UPCASE(&missing) = DELETE %THEN
		%DO;
			IF &var &operation &value THEN
				DELETE;
		%END;
%MEND;