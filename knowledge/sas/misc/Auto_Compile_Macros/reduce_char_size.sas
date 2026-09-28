/* Copyright (c) 2023 by SAS Institute Inc., Cary, NC USA 27513 */

%macro reduce_char_size(inlib=, dsin=, outlib=, dsout=, buffer=);
	proc contents data=&inlib..&dsin. out=content order=varnum noprint; run;	

	proc sql noprint;
		select name, varnum into :names separated by " ", :varnums separated by " " from content where type eq 2;
	quit;
	%let n=&sqlobs.;
	%put &=n. &=names &=varnums.;

	data var_length;
		set &inlib..&dsin(keep=&names.);
		%do i=1 %to &n.;
			%let name = %scan(&names.,&i.," ");
			%let var = %scan(&varnums.,&i.," ");
			l_&var. = length(&name.);
		%end;
	run;

	proc means data=var_length(keep=l_:) noprint;
		var _numeric_;
		output out=max_length_values(drop=_type_ _freq_) max= / autoname;
	run;

	proc transpose data=max_length_values out=max_length;
		var _numeric_;
	run;

	data max_length(drop=_name_ col1);
		set max_length;
		varnum_max = input(scan(_name_,2,"_"),best.);
		len	 = ceil(col1 * &buffer.);
	run;

	proc sql noprint nowarnrecurs;
		create table content as
		select t1.*, t2.len 
		from content t1
		left join max_length t2 on (t1.varnum = t2.varnum_max);
	quit;

	proc sql noprint;
		select name, len into :names separated by " ", :lengths separated by " " from content where type eq 2;
	quit;
	%let n=&sqlobs.;
	%put &=n. &=names &=lengths.;

	data &outlib..&dsout.(drop=
		%do i=1 %to &n.;
			%let name 	= %scan(&names.,&i.," ");
			&name._old 
		%end;
		);
	
		%do i=1 %to &n.;
			%let name 	= %scan(&names.,&i.," ");
			%let len	= %scan(&lengths.,&i.," ");
			attrib &name. length=$&len.;
		%end;
		set &inlib..&dsin.(rename=(
			%do i=1 %to &n.;
				%let name 	= %scan(&names.,&i.," ");
				&name. = &name._old
			%end;
			));

			%do i=1 %to &n.;
				%let name 	= %scan(&names.,&i.," ");
				&name. = &name._old;
			%end;
	run;

	proc datasets library=work kill noprint; run; quit;

%mend reduce_char_size;
/*%reduce_char_size(inlib=smb_base, dsin=demo_fpb, outlib=smb_stg, dsout=smb_fpb_small, buffer=%str(1.1));*/
