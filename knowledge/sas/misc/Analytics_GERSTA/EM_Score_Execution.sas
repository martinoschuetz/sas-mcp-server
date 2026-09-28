libname fcslib "D:\DATEN\QUELLEN";

data fcslib.scores;
  set fcslib.retail_score;
  
%include "D:\DATEN\MINING\RETAIL\Workspaces\EMWS\Score\PATHPUBLISHSCORECODE.sas";
  


SCORE=EM_EVENTPROBABILITY;
format SCORE 8.4;
keep KUNDEN_ID SCORE;
run;
 


