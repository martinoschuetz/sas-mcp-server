options dsaccel="any" ds2accel="any";
/* *** NOTE: setting this option is required by DQ Accelerator           *** */
option set=SAS_HADOOP_CONFIG_PATH="&SAS_HADOOP_CONFIG_PATH.";

/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing DQ Accelerator                                              */
/* ------------------------------------------------------------------------- */
libname myhive hadoop server="&HIVESERVER." user="&SCHEMA." subprotocol=hive2 schema=&SCHEMA.;

/* ------------------------------------------------------------------------- */
proc delete data=myhive.SampleNames; run; 
proc delete data=myhive.StandardizedNames; run; 

data myhive.SampleNames; 
	ID= _n_; 
	length Name $50; 
	input Name $char50.;
datalines;
BETH HOGAN
Janet viselli
Sarah Gillis
Bill hotchkiss
dr karen leary, phd
Matthew Mullen
BARB Desisti
Kelly M. Howell
Richard Benjamin II
William Howey
Carrie Govelitz
mr. Michael Steed
Dan DePumpo
Brauer, Robert Joseph
Thomas Martin jr
; 
run;


/* ------------------------------------------------------------------------- */
proc ds2 bypartition=yes ds2accel=yes;
	ds2_options trace;

	thread t_pgm / overwrite=yes; 
		dcl package dq dq(); 

		dcl varchar(256) _ERR_;
		dcl varchar(256) Standardized;
		keep ID Name Standardized _ERR_; 

		method check_err(); 
			_ERR_ = null;
			if dq.hasError() then _ERR_ = dq.getError(); 
		end; 

		method init(); 
			dq.loadLocale('ENUSA'); 
		end; 

		method run(); 
			set myhive.SampleNames; 
			Standardized = dq.standardize('Name', Name); 
			check_err(); 
			output; 
		end;

	endthread;

	data myhive.StandardizedNames (overwrite=yes); 
		declare thread t_pgm t; 

		method run(); 
			set from t; 
		end;

	enddata;

run; quit;
