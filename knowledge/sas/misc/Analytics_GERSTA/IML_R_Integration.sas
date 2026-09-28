
libname mydata "C:\DATEN\QUELLEN";


/* Beispiel für R Code-Call Einbettung */
title "R Code Integration";

data mydata.test;
set mydata.dm_hmeq_train;
run;


proc iml;
  call ExportDataSetToR("MYDATA.TEST","export");

  submit /R;
     attach(export)
	  glm.BAD <- glm(BAD~CLAGE+DEROG+DELINQ+NINQ+REASON+JOB+YOJ,binomial)
     export$SCORE<-predict(glm.BAD, newdata=export, type="response")
  endsubmit;
    call ImportDataSetFromR("MYDATA.TEST2","export");
quit;

PROC print data=mydata.test2(obs=10);
var _all_;
run;
