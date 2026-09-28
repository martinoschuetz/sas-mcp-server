%MACRO Concentrate(data,var,id);
	*** Sort by ID and VALUE;
	PROC SORT DATA=&data(keep=&var &id) OUT=_conc_;
		BY &id DESCENDING &var;
	RUN;

	*** Calculation of the SUM per ID;
	PROC MEANS DATA=_conc_ NOPRINT;
		VAR &var;
		BY &id;
		OUTPUT out = _conc_sum_(DROP=_type_ _freq_) SUM=&var._sum;
		WHERE &var ge 0;
	RUN;

	*** Merge the sum to the original sorted dataset;
	DATA _conc2_;
		MERGE _conc_
			_conc_sum_;
		BY &id;

		IF FIRST.&id THEN
			&var._cum=&var;
		ELSE &var._cum+&var;
		&var._cum_rel=&var._cum/&var._sum;

		IF LAST.&id AND NOT FIRST.&id THEN
			skip = 1;
		ELSE skip=0;
	RUN;

	*** Calcuation of the median per ID;
	PROC UNIVARIATE DATA=_conc2_ noprint;
		BY &id;
		VAR &var._cum_rel;
		OUTPUT out=concentrate_&var. MEDIAN=&var._conc;
		WHERE skip =0;
	RUN;

%MEND;