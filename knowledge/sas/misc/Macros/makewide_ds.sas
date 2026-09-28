%MACRO makewide_ds(DATA=,OUT=,COPY=,ID=,VAR=,
			TIME=Measurement);
	*** Part 1 - Creating a list of Measurement IDs;
	PROC FREQ DATA = &data NOPRINT;
		TABLE &time / OUT = distinct (DROP = count percent);
	RUN;

	DATA _null_;
		SET distinct END = eof;
		FORMAT _string_ $32767.;
		RETAIN _string_;
		_string_ = CATX(' ',_string_, &time);

		IF eof THEN
			DO;
				CALL SYMPUT('list',_string_);
				CALL SYMPUT('max',_n_);
			END;
		RUN;

		*** Part 2 - Using a SAS datastep for the transpose;
		DATA &out;
			SET &data;
			BY &id;
			RETAIN %DO i= 1 %to &max;
			&var%SCAN(&list,&i)
			%END;
			;
			IF FIRST.&id THEN
				DO;
					%DO i= 1 %TO &max;
						&var%SCAN(&list,&i)=.;
					%END;
					;
				END;

			%DO i = 1 %TO &max;
				IF &time = %SCAN(&list,&i) THEN
					DO;
						&var%SCAN(&list,&i) = &var;
					END;
			%END;

			IF LAST.&id THEN
				OUTPUT;
			KEEP &id &copy %DO i= 1 %to &max;
			&var%SCAN(&list,&i) %END;;
		RUN;

%MEND;