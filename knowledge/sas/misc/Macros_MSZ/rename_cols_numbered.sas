/*
Renames columns with consecutive numbers by type (character, numeric) for very wide table.
If prefix is set all columns get a common prefix.
Blocks is partitioning the Variable Names into groups in order not to run into overflow in SQL with long Variable names.
Blocks Minimum = 1, opimal sum(length(Varname))/32000;
*/
options mprint;

%macro rename_cols_numbered(dsin=, dsout=, blocks=, prefix=);

	proc contents data=&dsin. out=contents noprint;	run;

	%do j=0 %to &blocks.-1;

		proc sql noprint;
			select name into : vars separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select varnum into : varnums separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select ifc(Type eq 1, 'N', 'C') into : Types separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select format into : fmt_names separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
		quit;
		%let N=&sqlobs.;
		/*
		%put &=vars.;
		%put &=varnums.;
		%put &=Types.;
		%put &=fmt_names;
		*/

		data tmp_&j.;
			set &dsin.;

			%do i=1 %to &n.;
				%let num = %scan(&varnums., &i., ' ');
				%let var = %scan(&vars., &i., ' ');
				%let typ = %scan(&Types., &i., ' ');
				%let fmt_name = %scan(&fmt_names., &i., ' ');
/*
				%put &=i.;
				%put &=num.;
				%put &=var.;
				%put &=typ.;
				%put &=fmt_name.;
*/
				%if %length(&prefix.) ne 0 %then
					%do;
						&prefix._&num._&typ.		= "%scan(&vars., &i., ' ')"n;
						label &prefix._&num._&typ.	= "&prefix._&num._&typ: %scan(&vars., &i., ' ')";
						%if %length(&fmt_name.) ne 0 %then
							%do;
								format &prefix._&num._&typ &fmt_name..;
							%end;
					%end;
				%else
					%do;
						&typ._&num.			="%scan(&vars., &i., ' ')"n;
						label &typ._&num.	="&typ._&num.: %scan(&vars., &i., ' ')";
						%if %length(&fmt_name.) ne 0 %then
							%do;
								format &typ._&num. &fmt_name..;
							%end;
					%end;
			%end;
		run;

		/* Keep might not work if one tight is not in the data. Suppress the error.*/
		options dkricond=nowarn;
		data tmp_&j.;
			%if %length(&prefix.) ne 0 %then
				%do;
					set tmp_&j.(keep=&prefix.:);
				%end;
			%else
				%do;	
					set tmp_&j.(keep=C_: N_:);
				%end;
		run;
		options dkricond=warn;
	
	%end;

	data &dsout.;
		merge tmp_:;
	run;

	proc datasets lib=work nodetails nolist nowarn;
		delete tmp_: /*contents*/;
	run;
%mend rename_cols_numbered;
/*
data class;
	set sashelp.class;
run;
%rename_cols_numbered(dsin=class, dsout=class_out_prefix, blocks=1, prefix=sashelp);

%rename_cols_numbered(dsin=class, dsout=class_out, blocks=1, prefix=%str());
*/