%MACRO Clus_Sample_Res (data = , id =, outsmp=, prop = 0.1, n=, seed=12345 );

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

	%IF &n EQ %THEN
		%let n = %SYSEVALF(&prop*&n0);

	DATA &outsmp;
		SET &data;
		BY &id;
		RETAIN smp_flag;

		IF smp_count < &n THEN
			DO;
				IF FIRST.&id THEN
					DO;
						id_count + 1;

						IF uniform(&seed)*(&n0 - id_count) < (&n - smp_count) THEN
							DO;
								smp_flag=1;
								OUTPUT;
							END;
					END;
				ELSE IF smp_flag=1 THEN
					DO;
						OUTPUT;

						IF LAST.&id THEN
							DO;
								smp_flag=0;
								smp_count + 1;
							END;
					END;
			END;

		DROP smp_flag smp_count;
	RUN;

%MEND;