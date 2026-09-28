%MACRO RestrictedSample(data=,sampledata=,n=);
	*** Count the number of observations in the input
	   dataset, without using PROC SQL or other table scans
	   --> Saves Time;
	DATA _NULL_;
		CALL SYMPUT('n0',STRIP(PUT(nobs,8.)));
		STOP;
		SET &data nobs=nobs;
	RUN;

	DATA &sampledata;
		SET &data;

		IF smp_count < &n THEN
			DO;
				IF RANUNI(123)*(&n0 - _N_) <= (&n - smp_count) THEN
					DO;
						OUTPUT;
						Smp_count+1;
					END;
			END;
	RUN;

%MEND;