%macro create_labels_c(ds=, var_key=, var_label=, fmt_name=);

			PROC SQL;
	CREATE TABLE WORK.freqs AS 
		SELECT DISTINCT t1.&var_key., t1.&var_label
			FROM &ds. t1;
	QUIT;

	DATA WORK._EG_CFMT;
		LENGTH label $ 40;
		SET freqs (KEEP=&var_key. &var_label. RENAME=(&var_key.=start &var_label.=label)) END=__last;
		RETAIN fmtname "&fmt_name." type "C";
		end=start;

		OUTPUT;

		IF __last = 1 THEN
			DO;
				hlo = "??";
				label = "my_missing";
				OUTPUT;
			END;
	RUN;

	PROC FORMAT LIBRARY=FORMATS CNTLIN=WORK._EG_CFMT; RUN;

	PROC SQL; DROP TABLE work.freqs, WORK._EG_CFMT;	QUIT;

%mend;