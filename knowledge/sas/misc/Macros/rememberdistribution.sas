%MACRO RememberDistribution(data=,vars=_NUMERIC_,lib=sasuser,stat=median);

	PROC MEANS DATA = &data NOPRINT;
		VAR &vars;
		OUTPUT OUT = &lib..train_dist_&stat &stat=;
	RUN;

	PROC TRANSPOSE DATA  = &lib..train_dist_&stat(DROP = _TYPE_ _FREQ_)
		OUT   = &lib..train_dist_&stat._tp(RENAME = (_NAME_ = Variable
		Col1   = Train_&stat));
	RUN;

%MEND;