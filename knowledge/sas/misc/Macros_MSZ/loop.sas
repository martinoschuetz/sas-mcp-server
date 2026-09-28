/* ---------------------------------------------------------------------------------------- */
/* Schritt 2: Dateien einlesen und appenden */
/* ---------------------------------------------------------------------------------------- */
%macro loop(lib=, path=, id=, read_routine=);
	%local dsid i rc fname2;
	%let dsid=%sysfunc(open(files,i));

	/* Read all files in a loop */
	%if &dsid %then
		%do;
			%do i=1 %to %sysfunc(ATTRN(&dsid,NOBS));
				%let rc=%sysfunc(fetchobs(&dsid,&i));
				%let fname2=%sysfunc(getvarc(&dsid,%sysfunc(varnum(&dsid,fname2))));

				%&read_routine.(ds=tmp&i., fn=&path.\&fname2., shortfn=&fname2.);
			%end;

			%let rc=%sysfunc(close(&dsid));
		%end;

	data &lib..&id.;
		set tmp1;
		stop;
	run;

	/* Append all temp files. */
	data &lib..&id.;
		set 
			%let dsid=%sysfunc(open(files,i));

		%if &dsid %then
			%do;
				%do i=1 %to %sysfunc(ATTRN(&dsid,NOBS));
					tmp&i.
				%end;

			%let rc=%sysfunc(close(&dsid));
			%end;
		;
	run;

	/* Delete temporary files */
	proc datasets lib=work;
		delete files tmp: hlp:;
	run;

%mend loop;