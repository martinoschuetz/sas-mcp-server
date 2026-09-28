/* Create test data for relabeling macro*/
/*
data work.class;
    set sashelp.class;
    label name="Name of student";
    label sex="Sex of student";
    label age="Age of student";
    label height="Height of student";
    label weight="Weight of stundent"
run;
proc print data=class label; run;
*/

/* Generate a dataset from sashelp.class which only contains the variable names and labels of this data set. Use proc contents. Write the resulting dataset to an excel file called contents in the folder c:\tmp */
/* Create a temporary SAS dataset containing variable names and labels */

%macro relabel_write(dsin=, excel_out=);

    proc contents data=&dsin. out=content(keep=name label type varnum) noprint; run;
    data content;
        set content;
        label_new = "";
    run;
    %put &=excel_out.;
    proc export data=content outfile="&excel_out." dbms=xlsx replace; run;

%mend relabel_write;

/* Test call */
/*
%relabel_write(dsin=work.class, excel_out=%str(/export/pvs/sasdata/homes/esgmsz/class_content.xlsx))
*/

/* Prep test data to be relabeled */
/*
data class_relabeled;
    set class;
run;
*/

%macro relabel(lib=, ds=, excel_in=);

	%local i name lab pair relabel_statement;
	%let relabel_statement=;

    proc import datafile="&excel_in." out=content_new dbms=xlsx replace; run;

    /* Collect variable names and new labels for relabeling. */
    proc sql noprint;
    	select name, label_new into :var_names separated by " ", :labels separated by "|" from content_new;
    quit;
    %let n_var_names=&sqlobs.;
    %put &=n_var_names. &=var_names.;
    %put &=labels.;
 
	%do i=1 %to &n_var_names.;
		%let name = %scan(&var_names., &i.,);
    	%let lab = %scan(%bquote(&labels.), &i., |);
	 	%let pair = %sysfunc(catx(=, "&name."n, "&lab."));
		%let relabel_statement=&relabel_statement. &pair.;
	%end;
	%put &=relabel_statement.;

	proc datasets lib=&lib. nolist;
		modify &ds.;
		label %quote(&relabel_statement.);
		run;
	quit;

%mend relabel;

/*
%relabel(ds=work.class_relabeled, excel_in=%str(/export/pvs/sasdata/homes/esgmsz/class_content_in.xlsx));
proc print data=class_relabeled label; run;
*/

