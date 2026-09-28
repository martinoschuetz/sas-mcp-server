
/*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$*/
/*     INTERMITTENT DEMAND MODEL (IDM) CANDIDATE LIST POPULATION      */
/*  This represents a macro which creates a nearly complete cross-    */
/*  section of all possible idm model combinations.                   */
/*  Author: Phil Weiss                                                */
/*  Written:  March 1, 2005                                           */
/*  Notes: Replace example code with refernces to your data           */
/*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$*/

options mlogic symbolgen macrogen; /* comment out after testing is finished */
%macro idmpop(modelnum,imethod,itrnsfm,smethod,strnsfm,boxnum,label);
   %if &itrnsfm=boxcox or &itrnsfm=Boxcox or &itrnsfm=BoxCox
      %then %let itrnsfm=Boxcox(&boxnum);
   %if &strnsfm=boxcox or &strnsfm=Boxcox or &strnsfm=BoxCox
      %then %let strnsfm=Boxcox(&boxnum);

  proc hpfidmspec
       modelrepository=work.idmmdls /* will only append new models if already created */
	   specname=idm&modelnum.
	   speclabel="&label";
	 idm interval=(method=&imethod. transform=&itrnsfm. select=mse)
	         size=(method=&smethod. transform=&strnsfm. select=mse);
  run; 
%mend idmpop;
%idmpop(1,simple,none,simple,none,0,Crostons Method);
%idmpop(2,simple,log,simple,log,0,Log of Crostons);
%idmpop(3,simple,sqrt,simple,sqrt,0,Sqrt of Crostons);
%idmpop(4,simple,logistic,simple,logistic,0,Logistic of Crostons);
%idmpop(5,simple,boxcox,simple,boxcox,0,Boxcox of Crostons);
%idmpop(6,simple,boxcox,simple,boxcox,-5,Boxcox-5 of Crostons);
%idmpop(7,simple,boxcox,simple,boxcox,5,Boxcox 5 of Crostons);

%idmpop(8,double,none,double,none,0,Brown Smoothing);
%idmpop(9,double,log,double,log,0,Log of Brown);
%idmpop(10,double,sqrt,double,sqrt,0,Sqrt of Brown);
%idmpop(11,double,logistic,double,logistic,0,Logistic of Brown);
%idmpop(12,double,boxcox,double,boxcox,0,Boxcox of Brown);
%idmpop(13,double,boxcox,double,boxcox,-5,Boxcox-5 of Brown);
%idmpop(14,double,boxcox,double,boxcox,5,Boxcox 5 of Brown);

%idmpop(15,linear,none,linear,none,0,Holts Method);
%idmpop(16,linear,log,linear,log,0,Log of Holt);
%idmpop(17,linear,sqrt,linear,sqrt,0,Sqrt of Holt);
%idmpop(18,linear,logistic,linear,logistic,0,Logistic of Holt);
%idmpop(19,linear,boxcox,linear,boxcox,0,Boxcox of Holt);
%idmpop(20,linear,boxcox,linear,boxcox,-5,Boxcox-5 Holt);
%idmpop(21,linear,boxcox,linear,boxcox,5,Boxcox 5 of Holt);

%idmpop(22,damptrend,none,damptrend,none,0,Dampened Trend);
%idmpop(23,damptrend,log,damptrend,log,0,Log of Dampened Trend);
%idmpop(24,damptrend,sqrt,damptrend,sqrt,0,Sqrt of Dampened Trend);
%idmpop(25,damptrend,logistic,damptrend,logistic,0,Logistic of Dampened Trend);
%idmpop(26,damptrend,boxcox,damptrend,boxcox,0,Boxcox of Dampened Trend);
%idmpop(27,damptrend,boxcox,damptrend,boxcox,-5,Boxcox-5 of Dampened Trend);
%idmpop(28,damptrend,boxcox,damptrend,boxcox,5,Boxcox 5 of Dampened Trend);

%* Other variations follow ;
%idmpop(29,simple,none,double,none,0,Crostons w/Brown Size);
%idmpop(30,simple,none,linear,none,0,Crostons w/Holt Size);
%idmpop(31,simple,none,damptrend,none,0,Crostons w/Dampened Size);
%idmpop(32,simple,log,double,log,0,Log of Crostons w/Brown Size);
%idmpop(33,simple,log,linear,log,0,Log of Crostons w/Holt Size);
%idmpop(34,simple,log,damptrend,log,0,Log of Crostons w/Damptrend Size);

%idmpop(35,bestn,auto,bestn,auto,0,Best IDM Model);

proc hpfselect modelrepository=work.idmmdls
     selectname=idmselect
     selectlabel="Subsetted IDM model selection list";
     spec idm2 idm3 idm4 idm5 idm6 idm7 idm8 idm9 idm10 idm11 idm12
	      idm13 idm14 idm15 idm16 idm17 idm18 idm19 idm20 idm21 idm21 idm22;
		/*  idm23 idm24 idm25 idm26 idm27 idm28 idm29 idm30 idm31 idm32 idm33 idm34 idm35; */
	 select criterion=mape;
run;
/* Run this later if necessary */
ods graphics on;
ods html body     = "test_b.html"
         frame    = "test_f.html"
         contents = "test_c.html";
ods listing close;
proc hpfdiag data=sasuser.tsd15282 outest=est  /* replace data set with your data and change other statements to reflect correct variables */
      modelrepository=sasuser.idmmdls;
   by part_number;
   forecast quantity_shipped_Sum;
   id ship_date interval=month;
run; 

proc hpfengine data=sasuser.tsd15282 out=out print=(select estimates) /* inevent=sasuser.idmevents */
   modelrepository=sasuser.idmmdls globalselection=idmselect;
   forecast quantity_shipped_Sum;
   id ship_date interval=month;
   by part_number;
run;
ods graphics off;
ods html close;
