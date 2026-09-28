/*
I also use this method to rename the variables specific to customers industry, products, ….
You can strengthen/weaken the relationship between variables and the target variable by changing the covariances.
*/

/* Hans Demo Data */

/*
binär:
geschlecht      0/1
jobstatus       0/1
verheiratet     0/1

metrisch:
alter           18-78
kontaktpunkte   00-05
anzahl schaden  00-03
*/
%let anz=500000;

proc delete data=hpadata.customers2013;
run;

proc delete data=hpadata.customers2014;
run;

/* 
Vorbereitung Showcase, Tabellen für ETL Part:
customers2013: historischer Kundenbestand bis 12.2013
*/
data hpadata.customers2013;
	array _a{8} _temporary_ (0,0,0,1,0,1,1,1);
	array _b{8} _temporary_ (0,0,1,0,1,0,1,1);
	array _c{8} _temporary_ (0,1,0,0,1,1,0,1);
	attrib   kunden_id length=$8
		datum length=8 format=date9.
		geschlecht length=3  /* 0:m, 1:f */
	jobstatus length=3   /* 0:arbeitslos, 1:beschäftigt */
	verheiratet length=3 /* 0:ja, 1:nein */
	kunde_alter length=8 format=best12.
	anz_kontakte length=8 format=best12.
	anz_schaeden length=8 format=best12.
	churn length=3 /* 0:nein, 1:ja */
	;
	/* freestyle */
	do i = 1 to &anz.;
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = _a{x};
		verheiratet  = _b{x};
		jobstatus    = _c{x};
		kunden_id    = "C"||put(i,z7.);
		kunde_alter = int(18 + ranuni(1)*60);

		do j = 6 to 12;
			datum    = mdy(j,1,2013);
			anz_kontakte = int(ranuni(1)*6);

			if anz_kontakte > 3 then
				anz_kontakte = 0;
			anz_schaeden= int(ranuni(1)*6);

			if anz_schaeden > 3 then
				anz_schaeden = 0;
			lp = 6. -0.015*(1-geschlecht) + 0.7*(1-verheiratet) + 0.6*(1-jobstatus) + 0.02*anz_kontakte - 0.05*kunde_alter - 0.1*anz_schaeden;

			/* Returns a random variate from a binomial distribution. */
			churn = ranbin(1,1,(1/(1+exp(lp))));
			output;
		end;
	end;

	k = i;

	/* jung, maennlich, arbeitslos, unverheiratet */
	do i = (1+k) to ((1+k)+(&anz./30));
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = 0;
		verheiratet  = 1;
		jobstatus    = 0;
		kunden_id    = "C"||put(i,z7.);
		kunde_alter = int(18 + ranuni(1)*10);

		do j = 6 to 12;
			datum    = mdy(j,1,2013);
			anz_kontakte = int(ranuni(1)*6);

			if anz_kontakte > 3 then
				anz_kontakte = 0;
			anz_schaeden= int(ranuni(1)*6);

			if anz_schaeden > 3 then
				anz_schaeden = 0;
			lp = 6. -0.015*(1-geschlecht) + 0.7*(1-verheiratet) + 0.6*(1-jobstatus) + 0.02*anz_kontakte - 0.05*kunde_alter - 0.1*anz_schaeden;

			/* Returns a random variate from a binomial distribution. */
			churn = ranbin(1,1,(1/(1+exp(lp))));
			output;
		end;
	end;

	k = i;

	/* best ager, weiblich, arbeitslos, verheiratet */
	do i = (1+k) to ((1+k)+(&anz./20));
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = 1;
		verheiratet  = 0;
		jobstatus    = 0;
		kunden_id    = "C"||put(i,z7.);
		kunde_alter = int(50 + ranuni(1)*28);

		do j = 6 to 12;
			datum    = mdy(j,1,2013);
			anz_kontakte = int(ranuni(1)*6);

			if anz_kontakte > 3 then
				anz_kontakte = 0;
			anz_schaeden= int(ranuni(1)*6);

			if anz_schaeden > 3 then
				anz_schaeden = 0;
			lp = 6. -0.015*(1-geschlecht) + 0.7*(1-verheiratet) + 0.6*(1-jobstatus) + 0.02*anz_kontakte - 0.05*kunde_alter - 0.1*anz_schaeden;

			/* Returns a random variate from a binomial distribution. */
			churn = ranbin(1,1,(1/(1+exp(lp))));
			output;
		end;
	end;

	drop x i j k lp;
run;

/* 
Vorbereitung Showcase, Tabellen für ETL Part:
customers2014: aktueller Kundenbestand
*/
data hpadata.customers2014;
	array _a{8} _temporary_ (0,0,0,1,0,1,1,1);
	array _b{8} _temporary_ (0,0,1,0,1,0,1,1);
	array _c{8} _temporary_ (0,1,0,0,1,1,0,1);
	attrib   kunden_id length=$8
	datum length=8 format=date9.
	geschlecht length=3  /* 0:m, 1:f */
	jobstatus length=3   /* 0:arbeitslos, 1:beschäftigt */
	verheiratet length=3 /* 0:ja, 1:nein */
	kunde_alter length=8 format=best12.
	anz_kontakte length=8 format=best12.
	anz_schaeden length=8 format=best12.
	;
	datum    = mdy(1,1,2014);

	/* freestyle */
	do i = 1 to (&anz.-150000);
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = _a{x};
		verheiratet  = _b{x};
		jobstatus    = _c{x};
		kunden_id    = "N"||put(i,z7.);
		kunde_alter = int(18 + ranuni(1)*60);
		anz_kontakte = int(ranuni(1)*6);

		if anz_kontakte > 3 then
			anz_kontakte = 0;
		anz_schaeden= int(ranuni(1)*6);

		if anz_schaeden > 3 then
			anz_schaeden = 0;
		output;
	end;

	k = i;

	/* jung, maennlich, arbeitslos, unverheiratet */
	do i = (1+k) to ((1+k)+(&anz./30));
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = 0;
		verheiratet  = 1;
		jobstatus    = 0;
		kunden_id    = "N"||put(i,z7.);
		kunde_alter = int(18 + ranuni(1)*10);
		anz_kontakte = int(ranuni(1)*6);

		if anz_kontakte > 3 then
			anz_kontakte = 0;
		anz_schaeden= int(ranuni(1)*6);

		if anz_schaeden > 3 then
			anz_schaeden = 0;
		output;
	end;

	k = i;

	/* best ager, weiblich, arbeitslos, verheiratet */
	do i = (1+k) to ((1+k)+(&anz./20));
		x = rantbl(1,0.28,0.18,0.14,0.14,0.03,0.09,0.08,0.06);
		geschlecht   = 1;
		verheiratet  = 0;
		jobstatus    = 0;
		kunden_id    = "N"||put(i,z7.);
		kunde_alter = int(50 + ranuni(1)*28);
		anz_kontakte = int(ranuni(1)*6);

		if anz_kontakte > 3 then
			anz_kontakte = 0;
		anz_schaeden= int(ranuni(1)*6);

		if anz_schaeden > 3 then
			anz_schaeden = 0;
		output;
	end;

	drop x i k;
run;

data hpadata.customers2014;
	set hpadata.customers2014;
	attrib   erstaquise length=$8
		erstvertrag length=$8
		geschlecht_text length=$8
		jobstatus_text length=$8
		altersklasse length=$8
		bundesland length=$8
	;
	by kunden_id;
	retain erstaquise "" erstvertrag "" bundesland "";

	if kunde_alter < 33 then
		altersklasse   = "18-32";
	else if kunde_alter < 50 then
		altersklasse  = "33-49";
	else if kunde_alter >= 50 then
		altersklasse = "50-99";

	if geschlecht = 0 then
		geschlecht_text = "M";
	else geschlecht_text = "W";

	if jobstatus = 0 then
		jobstatus_text = "Nein";
	else jobstatus_text = "Ja";

	if first.kunden_id then
		do;
			x = int(ranuni(1)*10);

			if x < 3 then
				erstaquise      = "e-Mail";
			else if x < 5 then
				erstaquise = "Postwurf";
			else if x < 8 then
				erstaquise = "Callcntr";
			else erstaquise               = "(andere)";
			x = int(ranuni(1)*10);

			if x < 6 then
				erstvertrag      = "Person";
			else erstvertrag               = "Sach";
			x = int(ranuni(1)*10);

			if x < 3 then
				bundesland      = "Hessen";
			else if x < 5 then
				bundesland = "Bayern";
			else if x < 7 then
				bundesland = "Bremen";
			else if x < 8 then
				bundesland = "Sachsen";
			else bundesland               = "Berlin";
		end;

	drop x;
run;

data hpadata.customers2013;
	set hpadata.customers2013;
	attrib   erstaquise length=$8
		erstvertrag length=$8
		geschlecht_text length=$8
		jobstatus_text length=$8
		altersklasse length=$8
		bundesland length=$8
	;
	by kunden_id;
	retain erstaquise "" erstvertrag "" bundesland "";

	if kunde_alter < 33 then
		altersklasse   = "18-32";
	else if kunde_alter < 50 then
		altersklasse  = "33-49";
	else if kunde_alter >= 50 then
		altersklasse = "50-99";

	if geschlecht = 0 then
		geschlecht_text = "M";
	else geschlecht_text = "W";

	if jobstatus = 0 then
		jobstatus_text = "Nein";
	else jobstatus_text = "Ja";

	if first.kunden_id then
		do;
			x = int(ranuni(1)*10);

			if x < 3 then
				erstaquise      = "e-Mail";
			else if x < 5 then
				erstaquise = "Postwurf";
			else if x < 8 then
				erstaquise = "Callcntr";
			else erstaquise               = "(andere)";
			x = int(ranuni(1)*10);

			if x < 6 then
				erstvertrag      = "Person";
			else erstvertrag               = "Sach";
			x = int(ranuni(1)*10);

			if x < 3 then
				bundesland      = "Hessen";
			else if x < 5 then
				bundesland = "Bayern";
			else if x < 7 then
				bundesland = "Bremen";
			else if x < 8 then
				bundesland = "Sachsen";
			else bundesland               = "Berlin";
		end;

	drop x;
run;