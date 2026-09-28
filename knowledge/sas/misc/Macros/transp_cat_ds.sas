%MACRO TRANSP_CAT_DS (DATA = , OUT = out, VAR = , ID =);
	*** PART1 - Aggregating multiple categories per subject;
	PROC FREQ DATA  = &data NOPRINT;
		TABLE &id * &var / OUT = out(DROP = percent);

		TABLE &var /  OUT = distinct (drop = count percent);
	RUN;

	*** PART2 - Assigning the list of categories into a macro-variable;
	DATA _null_;
		SET distinct END = eof;
		FORMAT _string_ $32767.;
		RETAIN _string_;
		_string_ = CATX(' ',_string_, &var);

		IF eof THEN
			DO;
				CALL SYMPUT('list',_string_);
				CALL SYMPUT('_nn_',_n_);
			END;
		RUN;

		*** PART3 - Using a SAS-datastep for the transpose;
		DATA &out;
			SET out;
			BY &id;
			RETAIN &list;

			IF FIRST.&id THEN
				DO;
					%DO i= 1 %TO &_nn_;
						%SCAN((&list),&i)=.;
					%END;
					;
				END;

			%DO i = 1 %TO &_nn_;
				IF &var = "%scan(&list,&i)" THEN
					%SCAN((&list),&i) = count;
			%END;

			IF LAST.&id THEN
				OUTPUT;
			DROP &var count;
		RUN;

%MEND;