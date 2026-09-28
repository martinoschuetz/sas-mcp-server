options mprint;

/* ToDo: Durchgehende ByGroup damit first läuft */


%macro fa_vs_cv(fcsdata=, libin=, libout=, file=, interval=, postfix=, bygroup=, measure=, range=/*FIT FORECAST*/, actual=); 

	proc sort data=&libin..outmodelinfo out=outmodelinfo_sorted;
		by &bygroup.;
	run;

	%put &=range;

	proc sort data=&libin..outstat(where=(_REGION_ eq "&range.")) out=outstat;
		by &bygroup.;
	run;

	/* Alle Performancemaße pro by-Gruppe in eine Tabelle */
	data &libout..&file._modelinfo;
		merge outmodelinfo_sorted outstat;
		by &bygroup.;
	run;

	/* Berechnen von FA und CV */
	data hlp2;
		set &libin..outfor;
		AE=abs(Error);

		if error = . then
			MAXE = .;
		else MAXE=max(Actual,Predict);
	run;

	proc sort data=hlp2; by &bygroup.; run;

	proc means data=hlp2 noprint;
		var Actual AE MAXE;
		output out=hlp2
			sum= ActualSum AESum MAXESum
			std= ActualStd AEStd MAXEStd
			mean= ActualMean AEMean MAXEMean;
		by &bygroup.;
	run;

	data hlp2;
		set hlp2;
		CV=ActualStd/ActualMean;
		FA=max(100*(1-AESum/MAXESum),0);
	run;

	data &libout..&file._modelinfo;
		merge 	&libout..&file._modelinfo
			hlp2(keep=&bygroup. CV FA);
		by &bygroup.;
	run;

	/* Berechnen von FA/CV für Random Walk */
	data fcsrw;
		set &libin..data(rename=(&actual.=actual));
			retain PREDICT;
		by &bygroup.;

		PREDICT = lag1(actual);
		if first.&bygroup. then PREDICT=.;
		ERROR = actual - PREDICT;
	run;

	/* Berechnen von FA und CV */
	data test1;
		set fcsrw;
		AE=abs(Error);

		if error = . then
			MAXE = .;
		else MAXE=max(Actual,Predict);
	run;

	proc sort data=test1;
		by &bygroup.;
	run;

	proc means data=test1 noprint;
		var Actual AE MAXE;
		output out=test2
			sum= ActualSum AESum MAXESum
			std= ActualStd AEStd MAXEStd
			mean= ActualMean AEMean MAXEMean;
		by &bygroup.;
	run;

	data test2;
		set test2;
		CV=ActualStd/ActualMean;
		FA=max(100*(1-AESum/MAXESum),0);
	run;

	ods graphics on;
	ods output ParameterEstimates=parms;

	proc glm data=test2;
		title "Cofficient of Variation vs. Forecast Accuracy for RandomWalk by group &postfix.";
		model FA = CV;
		output out=glm_output predicted=glm_pred residual=glm_resid ;
	run;
	quit;

	data _null_;
		set parms;
		if Parameter eq 'Intercept' then call symput('Intercept',Estimate);
		if Parameter eq 'CV'		then call symput('Slope',Estimate);
	run;
	%put &=Intercept;
	%put &=Slope;

	/* Prozentualer Umsatz der Parameter die über der Forecast Value Added Line liegen. S.O.*/
	proc glm data=&libout..&file._modelinfo;
		title "Cofficient of Variation vs. Forecast Accuracy for Forecast Server Model by group &postfix.";
		model FA = CV;
		output out=glm_output predicted=glm_pred residual=glm_resid;
	run;

	quit;

	data hlp3;
		set glm_output/*(where=(_region_='FIT'))*/;
		id = catx('|',%sysfunc(tranwrd(%quote(&bygroup),%str( ),%str(,))));
	run;

	ods graphics on / imagemap; /* enable data tips */
	title "CV vs FA coloured by Model Name";

	proc sgplot data=hlp3;
		styleattrs datacontrastcolors=(pink blue red black green yellow);
		scatter x=CV y=FA / tip=(id CV FA _modeltype_ &measure.) group=_model_;
		lineparm x=0 y=&Intercept. slope=&Slope.;
	run;

	data hlp4;
		set hlp3(where=(&measure. < 10000));
		dlab = substrn(_modeltype_,1,1);
	run;

	title "CV vs FA coloured by &measure. and model name";

	proc sgplot data=hlp4;
		scatter x=CV y=FA / tip=(id CV FA _model_ &measure.) 
			colorresponse=&measure. colormodel=(cxFAFBFE cx667FA2 cxD05B5B)/*TwoColorRamp*/
			markerattrs=(symbol=CircleFilled size=8)  /* big filled markers */ datalabel=dlab;  /* add labels to markers */
		lineparm x=0 y=&Intercept. slope=&Slope.;
	run;

	ods graphics off;
%mend fa_vs_cv;

libname results "D:\FCS\Projects\Geratewerk_Month_Okt16\hierarchy\MLFB";

%fa_vs_cv(libin=results, libout=work, file=abt_geraetewerk_raw, interval=month, postfix=postfix,bygroup=MLFB, measure=MAPE, range=FORECAST, actual=BESTELLMENGE);