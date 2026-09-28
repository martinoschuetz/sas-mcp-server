/*************************************************************
 Exportiert den Textinhalt einer Variablen in seperate TXT-Files.
/*************************************************************/

%macro textvar_to_files(dataset=,textvar=,outdir=,nobs=); 

/*
proc sql noprint;
  select count(*) into :nobs from &dataset.;
quit;
*/
%DO obs = 1 %TO &nobs.;
	data _null_;
	   set &dataset. (obs=&obs.);
		if _n_ = &obs. then do;
			file "&outdir.\&obs..txt";
			put &textvar.;	
		end;
	run;
%END;

%mend textvar_to_files;

%textvar_to_files(
	dataset = staging.aufschrei,
	textvar = text,
	outdir  = &toptexte.,
	nobs	= 100
)


