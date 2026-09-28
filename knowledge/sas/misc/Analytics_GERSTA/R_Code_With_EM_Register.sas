data sample;
	set &EM_IMPORT_DATA;
run;

proc iml;
	call ExportDataSetToR("Sample","export");
	submit /R;
	attach(export)
		glm.HIGHRISK <- glm(HIGHRISK_STATUS~CUST_DURATION+AGE+TRX_AMOUNT_AVG_LM,binomial)
		export$P_1<-predict(glm.HIGHRISK, newdata=export, type="response")
		endsubmit;
	call ImportDataSetFromR("WORK.EMCODE_TRAIN","export");
quit;

data WORK.EMCODE_TRAIN;
	set WORK.EMCODE_TRAIN;
	length P_0 8;
	P_0=1-P_1;
	Score=P_1;
	label Score="Score Value";
run;

title "Sample Score Table";

proc print data=WORK.EMCODE_TRAIN(obs=20) noobs label;
	var CUST_ID AGE CUST_DURATION AGE Score;
run;

title "Descriptive Statistics for Score - Demographic Profile Breakdown";

proc sort data=WORK.EMCODE_TRAIN;
	by cust_Seg gender;
run;

proc means data=WORK.EMCODE_TRAIN;
	var Score;
	class cust_seg gender;
run;

%em_register(key=Scored, type=DATA);

data &em_user_SCored;
	set WORK.EMCODE_TRAIN;
run;

%em_report(Autodisplay=Y, key=Scored, viewtype=Data,description=Score Table from R);
%em_report(Autodisplay=Y, key=Scored, viewtype=Histogram,X=SCORE, description=Score Distribution Histogram);