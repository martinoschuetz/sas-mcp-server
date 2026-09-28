%MACRO MAKELONG(DATA=,OUT=,COPY=,ID=,ROOT=,MEASUREMENT=Measurement);
	*** Define a help macro;
%MACRO MAKELONG_BASIS(DATA=,OUT=,COPY=,ID=,ROOT=,MEASUREMENT=Measurement);
	*** Macro that transposes one variable per by-group;
	*** Dr. Gerhard Svolba, May 2nd 2008 - Rel 2.1;
	PROC TRANSPOSE DATA = &data(keep = &id &copy &root.:)
		OUT  = &out(rename = (col1 = &root))
		NAME = _measure;
		%IF &ID ne %THEN
			%DO;
				BY &id &copy;
			%end;
	RUN;

	*** Create variable with measurement number;
	DATA &out;
		SET &out;
		FORMAT &measurement 8.;
		_measure=upcase(_measure);
		&Measurement = INPUT(TRANWRD(_measure,upcase("&root"),''),8.);
		DROP _measure;
	RUN;

%MEND;

*** Calculate number of variables;
%LET c=1;

%DO %WHILE(%SCAN(&root,&c) NE);
	%LET c=%EVAL(&c+1);
%END;

%LET nvars=%EVAL(&c-1);

%IF &nvars=1 %then
	%do;
		%*** macro is  called with only one variable;
		%MAKELONG_BASIS(data=&data, out = &out, copy=&copy, id=&id, root=&root,measurement=&measurement);
	%END;

%** end: only 1 variable;
%ELSE
	%DO;
		** more then 2 vars;
		%DO i = 1 %TO &nvars;
			%MAKELONG_BASIS(data=&data, out = _mw_tmp_&i., copy=&copy, id=&id, root=%scan(&root,&i),MEASUREMENT=&Measurement);
		%END;

		*** end do loop;
		data &out;
			%IF &ID ne %THEN
				%DO;
					merge %do i = 1 %to &nvars;
					_mw_tmp_&i.
				%end;
			;
			by &id;
	%END;
%ELSE
	%DO;
		%do  i = 1 %to &nvars;
			set _mw_tmp_&i.;
		%end;
	%END;
		run;

%END;
%MEND;