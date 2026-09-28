%MACRO SamplingVAR(eventvar=,eventrate=);
	FORMAT Sampling 8.1;

	IF &eventvar=1 THEN
		Sampling=101;
	ELSE IF &eventvar=0 THEN
		Sampling=(&eventrate*100)/(RANUNI(34)*(1-&eventrate)+&eventrate);
%MEND;