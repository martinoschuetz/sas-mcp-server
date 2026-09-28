/* This macro list all files of a certain type in a folder. Specify the type in capital letters, e.g. ZIP. */
%macro create_file_list(folder=,ftype=);
	filename mydir "&folder.";

	/* Specify your folder path here */
	data &ftype._files;
		length filename $256;
		prefix_count=0;	
		dir_id=dopen("mydir");

		if dir_id > 0 then do;
			num_files=dnum(dir_id);

			do i=1 to num_files;
				filename=dread(dir_id, i);

				/* Check if filename ends with prefix like ".zip" (case-insensitive) */
				if upcase(substr(filename, length(filename)-3))=".%upcase(&ftype.)" then do;
					prefix_count = prefix_count + 1;
					output;
				end;
			end;
			rc=dclose(dir_id);
		end;
		else put "ERROR: Cannot open directory &root_path.";
	run;

	proc print data=&ftype._files;
		title "&ftype. Files in &root_path.";
	run;
%mend create_file_list;