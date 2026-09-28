%MACRO Clus_Sample (data = , id =, outsmp=, prop = 0.1, n=, seed=12345 );
	/*** Macro for clustered unrestricted sampling
	     Gerhard Svolba, Feb 2005
	     The macro draws a clustered sample in one datastep.
	     The exact sample count or sample proportion is not
	     controlled.
	     Macro Parameters:
	     DATA  The name of the base dataset
	           The name of the sample dataset will be created 
	           as DATA_SMP_<sample count (n)>
	     ID    The name of the ID-Variable, that identifes the
	           subject or BY group;
	     PROP  Sample Proportion as a number from 0 to 1
	     N     Sample count as an absolute number 
	     SEED  Seed for the random number function;
	    Note that PROP and N relate to the distinct ID-values;
	***/
	DATA _test_;
		SET &data;
		BY &ID;

		IF first.&id;
	RUN;

	DATA _NULL_;
		CALL SYMPUT('n0',STRIP(PUT(nobs,8.)));
		STOP;
		SET _test_ nobs=nobs;
	RUN;

	%IF &n NE %THEN
		%let prop = %SYSEVALF(&n/&n0);

	DATA &outsmp;
		SET &data;
		BY &id;
		RETAIN smp_flag;

		IF FIRST.&id AND RANUNI(&seed) < &prop THEN
			DO;
				smp_flag=1;
				OUTPUT;
			END;
		ELSE IF smp_flag=1 THEN
			DO;
				OUTPUT;

				IF LAST.&id THEN
					smp_flag=0;
			END;

		DROP smp_flag;
	RUN;

%MEND;