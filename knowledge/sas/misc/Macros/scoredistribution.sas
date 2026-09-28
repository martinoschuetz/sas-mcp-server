%MACRO ScoreDistribution(data=,vars=_NUMERIC_,lib=sasuser,stat=median,alert=0.1);

	PROC MEANS DATA = &data NOPRINT;
		VAR &vars;
		OUTPUT OUT = &lib..score_dist_&stat &stat=;
	RUN;

	PROC TRANSPOSE DATA  = &lib..score_dist_&stat(DROP = _TYPE_ _FREQ_)
		OUT   = &lib..score_dist_&stat._tp(RENAME = (_NAME_ = Variable
		Col1   = Score_&stat));
	RUN;

	PROC SORT DATA = &lib..train_dist_&stat._tp;
		BY variable;
	RUN;

	PROC SORT DATA = &lib..score_dist_&stat._tp;
		BY variable;
	RUN;

	DATA &lib..compare_&stat;
		MERGE &lib..train_dist_&stat._tp &lib..score_dist_&stat._tp;
		BY variable;
		DIFF = (Score_&stat - Train_&stat);

		IF Train_&stat NOT IN (.,0) THEN
			DIFF_REL = (Score_&stat - Train_&stat)/Train_&stat;
		Alert = (ABS(DIFF_REL) > &alert);
	RUN;

	TITLE Alertlist for Distribution Change;
	TITLE2 Data = &data -- Alertlimit >= &alert;

	PROC PRINT DATA = &lib..compare_&stat;
	RUN;

	TITLE;
	TITLE2;
%MEND;