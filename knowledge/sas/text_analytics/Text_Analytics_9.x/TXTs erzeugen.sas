/*************************************************************

Exportiert den Textinhalt einer Variablen in seperate TXT-Files.

/*************************************************************/
%macro textvar_to_files(dataset=,textvar=,outdir=);

	proc sql noprint;
		select count(*) into :nobs from &dataset;
	quit;

	%DO obs = 1 %TO &nobs;

		data _null_;
			set &ds (obs=&obs);

			if _n_ = &obs then
				do;
					file "&outdir.\&obs..txt";
					put &textvar;
				end;
		run;

	%END;
%mend textvar_to_files;

%textvar_to_files(
	dataset = DATA.AUFSCHREI_TWEETS_HASRT,
	textvar = text,
	outdir  = C:\Projekte\Demo\Aufschrei\data\texte
	)