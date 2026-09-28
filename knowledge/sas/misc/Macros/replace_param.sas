/* Replaces marked parts, e.g. "<NUMBER>" in a file. 
	fwrite to puffer not working. Finally, string substitution to be done. */

%let i=1;
%macro replace_param(file_in=, file_out=);

	/* Open input file for reading */
	%let rcin=%sysfunc(filename(fin, &file_in.));
   	%let fid=%sysfunc(fopen(&fin.,I,0,V));
	%if &fid. = 0 %then
   		%do;
			%put %sysfunc(sysmsg());
			%put Cannot open input file &file_in.!;
		%end;
		
	/* Open output file for writing */
	%let rcout=%sysfunc(filename(fon, &file_out.));
   	%let fod=%sysfunc(fopen(&fon.,U,0,V));
	%if &fod. = 0 %then
   		%do;
			%put %sysfunc(sysmsg());
			%put Cannot open output file &file_in.!;
		%end;

	%do %while(%sysfunc(fread(&fid.)) = 0 );
		%let rc=%sysfunc(fget(&fid., line_in, 32000));
		%put &line_in;
		%let rc=%sysfunc(fput(&fod., &line_in.));
		%let rc=%sysfunc(fwrite(&fod));
		%put %sysfunc(sysmsg());
	%end;

	%let rc=%sysfunc(fclose(&fid));
	%let rc=%sysfunc(filename(&fin.));

	%let rc=%sysfunc(fclose(&fod));
	%let rc=%sysfunc(filename(&fon.));
	
%mend replace_param;

%replace_param(	file_in=%str(&folder_path./parameter_files/apa_params_incremental_part.txt),
				file_out=%str(&folder_path./parameter_files/hugo.txt));  /* Call the macro to process the file */


