%MACRO AlertNumericMissing (data=,vars=_NUMERIC_,alert=0.2);

	PROC MEANS DATA = &data NMISS NOPRINT;
		VAR &vars;
		OUTPUT OUT = miss_value NMISS=;
	RUN;

	PROC TRANSPOSE DATA  = miss_Value(DROP = _TYPE_)
		OUT   = miss_value_tp;
	RUN;

	DATA miss_value_tp;
		SET miss_value_tp;
		FORMAT Proportion_Missing 8.2;
		RETAIN N;

		IF _N_ = 1 THEN
			N = COL1;
		Proportion_Missing = COL1/N;
		Alert = (Proportion_Missing >=  &alert);
		RENAME _name_ = Variable
			Col1 = NumberMissing;

		IF _name_ = '_FREQ_' THEN
			DELETE;
	RUN;

	TITLE Alertlist for Numeric Missing Values;
	TITLE2 Data = &data -- Alertlimit >= &alert;

	PROC PRINT DATA = miss_value_tp;
	RUN;

	TITLE;
	TITLE2;
%MEND;