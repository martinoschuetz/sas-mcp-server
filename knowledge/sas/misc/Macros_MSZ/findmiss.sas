%macro findmiss(ds,macvar);
	%local noteopt;
	%let noteopt=%sysfunc(getoption(notes));
	option nonotes;

	*ds is the data set to parse for missing values;
	*macvar is the macro variable that will store the list of empty columns;
	%global &macvar;

	proc format;
		value nmis  .-.z =' ' other='1';
		value $nmis ' '=' ' other='1';
	run;

	ods listing close;
	ods output OneWayFreqs=OneValue(
		where=(frequency=cumfrequency 
		AND CumPercent=100));

	proc freq data=&ds;
		table _All_ / Missing;
			format _numeric_ nmis. 
				_character_ $nmis.;
	run;

	ods listing;

	data missing(keep=var);
		length var $32.;
		set OneValue end=eof;

		if percent eq 100 AND sum(of F_:) < 1;
		var = scan(Table,-1,' ');
		run;

		proc sql noprint;
			select var into: &macvar separated by " "
				from missing;
		quit;

		option &noteopt.;
%mend;