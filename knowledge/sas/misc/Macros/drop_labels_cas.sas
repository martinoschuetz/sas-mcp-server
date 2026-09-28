/*
	Macro drops all labels of a cas table 
*/
/*
options mprint;

proc casutil;
	load data=sashelp.class outcaslib="casuser" casout="class";
run;

data casuser.class_label;
	set casuser.class;
	attrib age 		label="Age of student";
	attrib Height	label="Height of student";
	attrib Name		label="Name of student";
	attrib sex		label="Sex of student";
	attrib weight	label="Weight of Student";
run;

proc cas;
	table.alterTable status=rc / 
		caslib="casuser" 
		columns={{name="Age", label=""},
		{name="Height", label=""},
		{name="Name", label=""},
		{name="Sex", label=""},
		{name="Weight", label=""}}  
		name="class_label";
	print rc;
quit;
*/

%macro drop_labels_cas(incaslib=, inds=);
	%local i var;

	proc contents data=&incaslib..&inds. out=out noprint;
	run;

	proc sql noprint;
		select name into :vars separated by ' ' from out;
	quit;

	%let N=&sqlobs.;
	%put The following &N. variables will be de-labeled: &vars.;
	%let var=%scan(&vars., 1);
	%put I=1 &=var.;

	proc cas;
		table.alterTable status=rc / 
			caslib="&incaslib." 
			columns={{name="&var.", label=""}

			%do i=2 %to &n.;
				%let var=%scan(&vars., &i.);
				%put &=i. &=var.;
				, {name="&var.", label=""}
			%end;

		}
		name="&inds.";
		print rc;
	quit;

%mend drop_labels_cas;

*%drop_labels_cas(incaslib=casuser, inds=class_label);