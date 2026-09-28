%MACRO REPLACE_MV(cols,mv=.,rplc=0);
	ARRAY varlist {*}  &cols;

	DO _i = 1 TO dim(varlist);
		IF varlist{_i} = &mv THEN
			varlist{_i}=&rplc;
	END;

	DROP _i;
%MEND;