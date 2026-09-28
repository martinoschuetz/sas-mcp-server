	/*	Macro for computation of binary classification performance measures 
	For Details see https://en.wikipedia.org/wiki/Precision_and_recall

	ToDo: 	Compute decide value based on posteriori probability and cut-off; %let cutoff=0.5;
			Convert actual and decide to character.
			Build mulitnomial version.
*/
%macro classifier_performance(ds=, actual=, decide=, outds_prefix=);

	title "Confusion Matrix";
	proc freq data=&ds.;
		table &actual. * &decide.;
	run;

	proc sql noprint;
		select count(*) as tn into: tn from &ds. where &actual.=0 and &decide.=0;
		select count(*) as tp into: tp from &ds. where &actual.=1 and &decide.=1;
		select count(*) as fp into: fp from &ds. where &actual.=0 and &decide.=1;
		select count(*) as fn into: fn from &ds. where &actual.=1 and &decide.=0;
	quit;

	%put DATEI = measures_&outds_prefix.;

	data measures_&outds_prefix.;
		attrib actual_col label="Column name holding given classification" format=$32.;
		attrib decide_col label="Column name holding model classification" format=$32.;

		attrib tp 	label="True Positives"	format=8.;
		attrib tn 	label="True Negatives" 	format=8.;
		attrib fp 	label="False Positives" format=8.;
		attrib fn 	label="False Negatives" format=8.;

		attrib tpr 	label="True Positive Rate ~ Sensitivity ~ Recall" 		format=percentn8.2;
		attrib tnr	label="True Negative Rate ~ Specifity"					format=percentn8.2;
		attrib ppv	label="Positive Predicted Value ~ Precision"			format=percentn8.2;
		attrib npv	label="Negative Predicted Value"						format=percentn8.2;
		attrib fpr	label="False Positive Rate ~ Fall-out  1 - Specifity"	format=percentn8.2;
		attrib fdr	label="False Discovery Rate"							format=percentn8.2;
		attrib fnr	label="False Negative Rate ~ Miss Rate"					format=percentn8.2;

		attrib accuracy label="Accuracy"									format=percentn8.2;
		attrib misclass label="Misclassification Rate"						format=percentn8.2;
		attrib f1score	label="F1 Score"									format=percentn8.2;
		attrib mcc		label="Matthews correlation coefficient"			format=best12.;
		attrib inform	label="Informedness = Sensitivity + Specificity - 1" format=best12.;
		attrib mark		label="Markedness = Precision + NPV - 1"			format=best12.;

		actual_col= "&actual.";
		decide_col= "&decide.";

		tp	= &tp; 	/* True Positives */
		tn	= &tn;	/* True Nevatives */
		fp	= &fp;	/* False Positives */
		fn	= &fn;	/* False Negatives */

		tpr	= tp/(tp+fn); /* True Positive Rate = sensitivity = recall */
		tnr	= tn/(fp+tn); /* True Negative Rate = specifity */
		ppv = tp/(tp+fp); /* Positive Predicted Value = precision */
		npv = tn/(tn+fn); /* Negative Predicted Value */
		fpr = fp/(fp+tn); /* False Positive Rate = fall-out = 1 - specifity */
		fdr = fp/(fp+tp); /* False Discovery Rate */
		fnr = fn/(fn+tp); /* False Negative Rate = Miss Rate */

		accuracy = (tp+tn)/(tp+tn+fp+fn);
		misclass = (fp+fn)/(tp+tn+fp+fn);
		/* 	F1 is the harmonic mean of precision and sensitivity, i.e.
		F1 = ((precision*recall)/(precision+recall))*/
		f1score	 = 2*tp/(2*tp+fp+fn);
		mcc		 = ((tp*tn) - (fp*fn))/sqrt((tp+fp) * (tp+fn) * (tn+fp) * (tn+fn)); /* Matthews correlation coefficient */
		inform	 = tpr + tnr - 1; /* Informedness = Sensitivity + Specificity - 1 */
		mark	 = ppv + npv - 1; /* Markedness = Precision + NPV - 1 */
	run;

	title "Model Fit Statistics";
	proc print data=measures_&outds_prefix. noobs label;
		var misclass accuracy ppv tpr f1score;
	run;

	title;
%mend; /* classifier_performance */
/*
data testdata;
	length actual decide 8.;
	input actual decide;
	datalines;
1 1
1 1
1 1
1 1
1 0
1 0
1 0
1 0
1 0
0 1
0 1
0 1
0 0
0 0
0 0
;

%classifier_performance(ds=testdata, actual=actual, decide=decide, outds_prefix=classifier_performance);
*/
