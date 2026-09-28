%MACRO TRANSP_CAT(DATA = , OUT = TRANSP, VAR = , ID =);

	PROC FREQ DATA  = &data NOPRINT;
		TABLE &id * &var / OUT = tmp(DROP = percent);
	RUN;

	PROC TRANSPOSE DATA = tmp
		OUT  = &out (DROP = _name_);
		BY &id;
		VAR count;
		ID &var;
	RUN;

%MEND;