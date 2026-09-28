%macro textvar_to_files(ds=,textvar=,idvar=,outdir=); 

proc sql noprint;
  select count(*) into :nobs from &ds;
quit;

%DO obs = 1 %TO &nobs;
	data _null_;
	   set &ds (obs=&obs);
		if _n_ = &obs then do;
			file "&outdir.\&obs..txt";
			put &textvar;	
		end;
	run;
%END;

%mend textvar_to_files;


%textvar_to_files(
	ds = EM.POSTS_FORUM,
	textvar = POST_TEXT,
	idvar = SMA_POST_ID,
	outdir  = &dir_txt_forum;
)