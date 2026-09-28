%MACRO MAKEWIDE (DATA=,OUT=out,COPY=,ID=,
			VAR=, TIME=time);

%MACRO MAKEWIDE_BASIS (DATA=,OUT=out,COPY=,ID=,
				VAR=, TIME=time);
	*** Macro that transposes one variable per by-group;
	*** Dr. Gerhard Svolba, May 2nd 2008 - Rel 2.1;
	PROC TRANSPOSE DATA   = &data
		PREFIX = &var
		OUT    = &out(DROP = _name_);
		%IF &ID ne %THEN
			%DO;
				BY  &id &copy;
			%END;

		VAR &var;
		ID  &time;
	RUN;

%MEND;

*** Calculate number of variables;
%LET c=1;

%DO %WHILE(%SCAN(&var,&c) NE);
	%LET c=%EVAL(&c+1);
%END;

%LET nvars=%EVAL(&c-1);

%IF &nvars=1 %then
	%do;
		%*** macro is  called with only one variable;
		%MAKEWIDE_BASIS(data=&data, out = &out, copy=&copy, id=&id, var=&var,time=&time);
	%END;

%** end: only 1 variable;
%ELSE
	%DO;
		** more then 2 vars;
		%DO i = 1 %TO &nvars;
			%MAKEWIDE_BASIS(data=&data, out = _mw_tmp_&i., copy=&copy, id=&id, var=%scan(&var,&i),time=&time);
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