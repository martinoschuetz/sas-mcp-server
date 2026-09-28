%LET LowerBoundary=0.25; 
%LET UpperBoundary=99.75; 

/* !!!!! DO NOT EDIT BELOW THIS LINE !!!!! */

/* author + date: SBXKOK Wednesday December 26th, 2007 */
/* PURPOSE OF THIS PROGRAM:                                                                       */ 
/* capping the extremes of the interval inputs after grouping the data into classification levels */ 
/* Dutch: aftoppen van de extremen van de interval inputs binnen crossclassificatiegroepen        */ 

/* The cross-classification groups are formed by all existing (!) combinations */ 
/* of the levels of the ROLE=CROSSID variables (max. 2!)                       */ 
/* 'existing' means: present in the training set (&EM_IMPORT_DATA)             */ 
/* The CROSSID vars need to have the CHARACTER DATA TYPE for this program to work */ 
/* This program will retain 2 CROSSID vars at the max (!) as              */ 
/* PROC UNIVARIATE supports a CLASS statement with 1 or 2 vars, not more! */ 

/* A permanent library called USERDATA should be available (with write permissions) */

/* options mprint source2;                        */
/* the above options are put in the start-up code */

proc datasets library=userdata nolist;
 delete Pctls               / memtype=DATA;
 delete extreme_percentiles / memtype=DATA;
run;
QUIT; 

%LET LowerBoundary=%trim(%left(&LowerBoundary));
%LET UpperBoundary=%trim(%left(&UpperBoundary)); 
data _NULL_;
 Length LowerBoundary  UpperBoundary 
        LowerBoundary_ UpperBoundary_  $6; 
 LowerBoundary="&LowerBoundary";
 UpperBoundary="&UpperBoundary";
 LowerBoundary_=TRANWRD(LowerBoundary,".","_");
 UpperBoundary_=TRANWRD(UpperBoundary,".","_");
 call symput('LowerBoundary_NoDot',strip(LowerBoundary_));
 call symput('UpperBoundary_NoDot',strip(UpperBoundary_));
run;

%PUT CLASSVARSunivariate =%EM_CROSSID; /* all EM_CROSSID vars */ 
%PUT number of CROSSID variables (#) =&EM_NUM_CROSSID; 
data _NULL_;
 Length CLASSVARSunivariate $72;
 if (&EM_NUM_CROSSID NE 0) then do; 
  CROSSID1 = scan("%left(%EM_CROSSID)",1,' ');
  CROSSID2 = scan("%left(%EM_CROSSID)",2,' ');
  CLASSVARSunivariate = 'CLASS ' !! strip(CROSSID1) !!' '!! strip(CROSSID2); 
  call symput('myCROSSID1',strip(CROSSID1)); 
  call symput('myCROSSID2',strip(CROSSID2)); 
  call symput('CLASSVARSunivariate',strip(CLASSVARSunivariate));
 end;
 else 
  call symput('CLASSVARSunivariate',' ');
run;
%PUT CLASSVARSunivariate =&CLASSVARSunivariate; /* list restricted to max. 2 vars, i.e first two EM_CROSSID vars */ 
 
proc univariate data=&EM_IMPORT_DATA noprint; /* data = incoming TRAINing data */
		&CLASSVARSunivariate ; 
		/* just above this line:                                                         */ 
		/* possible CLASS statement with max. 2 CLASSvars (first two vars from %EM_CROSSID) */
		/* The CLASS statement specifies one or two variables                   */ 
		/* that the procedure uses to group the data into classification levels */ 
      var %EM_INTERVAL_INPUT ;
      output out=userdata.Pctls 
                       pctlpts  =  0   &LowerBoundary         &UpperBoundary         100 
                       pctlpre  = %EM_INTERVAL_INPUT 
                       pctlname = _0  _&LowerBoundary_NoDot  _&UpperBoundary_NoDot  _100;
run;

%MACRO varnamelist(dsn);
%global varlist;
%local  starti;

/* The CROSSID vars (max=2) are the ones in the front of the dataset */
%IF       %sysevalf(&EM_NUM_CROSSID >= 2,boolean) %THEN %do; %let starti=3; %end;
%ELSE %IF %sysevalf(&EM_NUM_CROSSID = 1, boolean) %THEN %do; %let starti=2; %end;
%ELSE %do; %let starti=1; %end;

%let dsid=%sysfunc(open(&dsn,i));
%let varlist=; 
%do i=&starti %to %sysfunc(attrn(&dsid,nvars));
   %let varlist=&varlist %sysfunc(varname(&dsid,&i));
%end;
%let rc=%sysfunc(close(&dsid));
%put varlist=&varlist;
%mend varnamelist;

%varnamelist(userdata.Pctls)
title;

data userdata.extreme_percentiles
		(keep= %substr(&CLASSVARSunivariate,7) 
             name Pctl_0 Pctl_&LowerBoundary_NoDot Pctl_&UpperBoundary_NoDot Pctl_100);
 Length name $32;
 set userdata.Pctls;
 array varnamelist(*) &varlist;
 do i= 1 to dim(varnamelist)/4; 
  posit=index (vname(varnamelist(i*4-3)),'_0');
  name =substr(vname(varnamelist(i*4-3)),1,posit-1);
  do j = 1 to 4;
        if j=1 then do; a=(i*4)-3; Pctl_0                    = varnamelist(a); end;  
   else if j=2 then do; a=(i*4)-2; Pctl_&LowerBoundary_NoDot = varnamelist(a); end;
   else if j=3 then do; a=(i*4)-1; Pctl_&UpperBoundary_NoDot = varnamelist(a); end;
   else if j=4 then do; a=(i*4)-0; Pctl_100                  = varnamelist(a); end;
   else;
  end;
  output;
 end;
run;
 
TITLE1 'GO TO << VIEW -- SCORING -- SAS CODE >> IN THE PULL DOWN MENUS'; 
TITLE2 'THERE YOU SHOULD FIND THESE OBSERVATIONS IN SCORE CODE FORMAT (if then else)'; 
TITLE3 'everything will be scored: train validation test + NEW DATA (i.e. score data)'; 
TITLE4 'score code will automatically be integrated in final data step (overall score code)'; 
TITLE5 ' '; 
TITLE6 'number of observations in userdata.extreme_percentiles = '; 
TITLE7 'number of interval inputs times number of existing CROSSID level combinations (max. ii x c1 x c2)'; 
TITLE8 'below are all interval inputs per existing CROSSID level combination'; 

proc print data=userdata.extreme_percentiles;
run;
TITLE; /* wipe out all titles */ 

			/*** Add Score Code ***/

%macro scorecode(file);
%IF       %sysevalf(&EM_NUM_CROSSID >= 2,boolean) %THEN %do; 
  data _null_;
   filename X "&file";
   FILE X;
    set userdata.extreme_percentiles end=last;
    by &myCROSSID1 &myCROSSID2; 
   if _N_=1 then do; put "IF 0 THEN put 'impossible';"; end;
   if first.&myCROSSID2=1 then do; 
   put "ELSE IF (&myCROSSID1 = '" &myCROSSID1 +(-1) "' AND &myCROSSID2 = '" &myCROSSID2 +(-1) "') THEN DO;"; 
   end; 
   put '  if      ' name ' < ' Pctl_&LowerBoundary_NoDot ;
   put '     then ' name ' = ' Pctl_&LowerBoundary_NoDot ';';
   put '  else if ' name ' > ' Pctl_&UpperBoundary_NoDot ;
   put '     then ' name ' = ' Pctl_&UpperBoundary_NoDot ';';
   put '  else;';
   if last.&myCROSSID2=1 then do; 
   put 'END;';
   end; 
   if last then do; put 'ELSE;'; end; 
  run; 
%end;
%ELSE %IF %sysevalf(&EM_NUM_CROSSID = 1, boolean) %THEN %do;
  data _null_;
   filename X "&file";
   FILE X;
    set userdata.extreme_percentiles end=last; 
    by &myCROSSID1; 
   if _N_=1 then do; put "IF 0 THEN put 'impossible';"; end; 
   if first.&myCROSSID1=1 then do; 
   put "ELSE IF &myCROSSID1 = '" &myCROSSID1 +(-1) "' THEN DO;"; 
   end; 
   put '  if      ' name ' < ' Pctl_&LowerBoundary_NoDot ;
   put '     then ' name ' = ' Pctl_&LowerBoundary_NoDot ';';
   put '  else if ' name ' > ' Pctl_&UpperBoundary_NoDot ;
   put '     then ' name ' = ' Pctl_&UpperBoundary_NoDot ';';
   put '  else;';
   if last.&myCROSSID1=1 then do; 
   put 'END;';
   end; 
   if last then do; put 'ELSE;'; end; 
  run; 
%end;
%ELSE %do; 
  data _null_;
   filename X "&file";
   FILE X;
    set userdata.extreme_percentiles;
   put 'if      ' name ' < ' Pctl_&LowerBoundary_NoDot ;
   put '   then ' name ' = ' Pctl_&LowerBoundary_NoDot ';';
   put 'else if ' name ' > ' Pctl_&UpperBoundary_NoDot ;
   put '   then ' name ' = ' Pctl_&UpperBoundary_NoDot ';';
   put 'else;';
  run;
%end; 
%mend scorecode;

%scorecode(&EM_FILE_EMFLOWSCORECODE);
%scorecode(&EM_FILE_EMPUBLISHSCORECODE);
/* end of program */
