%let VDB_GRIDHOST=eecvm0200.demo.sas.com;
%let VDB_GRIDINSTALLOC=/opt/sasinside/TKGrid/EEP=C04/14w41/TKGrid;
options set=GRIDHOST="eecvm0200.demo.sas.com";
options set=GRIDINSTALLOC="/opt/sasinside/TKGrid/EEP=C04/14w41/TKGrid";

/* Register Table Macro */
%macro registertable(REPOSITORY=Foundation, REPOSID=, LIBRARY=, TABLE=, FOLDER=, TABLEID=, PREFIX=);

	/* Mask special characters */
	
	%let REPOSITORY	=%superq(REPOSITORY);
	%let LIBRARY	=%superq(LIBRARY);
	%let FOLDER		=%superq(FOLDER);
	%let TABLE		=%superq(TABLE);

	%let REPOSARG=%str(REPNAME="&REPOSITORY.");
	%if ("&REPOSID." ne "") %then %let REPOSARG=%str(REPID="&REPOSID.");

	if ("&TABLEID." ne "") 	%then %let SELECTOBJ=%str(&TABLEID.);
							%else %let SELECTOBJ=&TABLE.;

	%if ("&FOLDER." ne "")	%then
		%put INFO: Registering &FOLDER./&SELECTOBJ. to &LIBRARY.library.;
	%else
		%put INFO: Registering &SELECTOBJ. to &LIBRARY. library.;

	proc metalib;
		omr (
			library="&LIBRARY."
			%str(&REPOSARG.)
			);
		%if ("&TABLEID." eq "")	%then %do
			%if ("&FOLDER." eq "") %then %do
				folder="&FOLDER.";
			%end;
		%end;
		%if ("&PREFIX" ne "") %then %do
			prefix="&PREFIX.";
		%end;
		select ("&SELECTOBJ.");
	run;
	quit;
%mend;