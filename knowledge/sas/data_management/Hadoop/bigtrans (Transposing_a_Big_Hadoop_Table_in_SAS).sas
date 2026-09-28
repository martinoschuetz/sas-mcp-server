/*******************************************************************************/
/* This programs assumes an input table with the folloing characteristics      */
/* A variable "by" which is the variable that will be in the by statement      */
/* A variable "id" which is the variable containing the identification of      */
/*                 new column names after transposition                        */
/* A variable "partition" which is unique within each value of the "by" var    */
/*                It is number determining how many partitions are present (20)*/
/* A variable "Target" which is binary (0/1) determining which values of the   */
/*                 "by" variable targets 0 or 1                                */
/* "hlib" is a hive, hdsf or lasr library hosting the table "filein"           */
/* "dlib" is a Base SAS library where the transposed table will be created     */
/*******************************************************************************/
options compress=yes;

%macro bigtrans(hlib,dlib,filein,fileout,by,id,var);
	/* Create a unique list of variables to name the transposed columns  */
	proc hpsummary data=&hlib..&filein. nway;
		performance details;
		class &id.;
		var &var.;
		output out=work.trait_freq(drop=_type_ _freq_) n=Freq;
	run;

	proc sql;
		select distinct cat("Trait_",&id.) into :alltraits separated by ' '
			from work.trait_freq where compress(&id.) ne '' and compress(&id.) not in ('null');
	quit;

	%put &alltraits.;

	data &fileout.;
		length &by. $70 Target $1 Partition $2 &alltraits. 8;
		stop;
	run;

	proc delete data=&dlib..&fileout.;
	run;

	%do i=0 %to 19;

		proc delete data=work.raw_sum;
		run;

		/* The Where statement below is to include observations in the specific partition */
		proc hpds2 data=&hlib..&filein.
			out=work.raw_sumary;
			performance details;

		data ds2gtf.out;
			method run();
				set {select * from ds2gf.in where (compress(partition) = compress("&i.") and compress(&id.) not in ('null'))};
			end;
		enddata;
		run;

		proc transpose data=work.raw_sumary prefix=trait_ out=work.raw_sum(drop=_name_);
			by &by. target partition;
			id &id.;
			var &var.;
		run;

		proc append base=&dlib..&fileout. data=work.raw_sum force;
		run;

		proc hpds2 data=work.raw_sum
			out=&hlib..&fileout.;
			performance details;

		data ds2gtf.out;
			method run();
				set ds2gtf.in;
			end;
		enddata;
		run;

		quit;

	%end;
%mend;