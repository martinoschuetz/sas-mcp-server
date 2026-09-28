%LET LowerBoundary=0.25;
%LET UpperBoundary=99.75; 

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
 Length LowerBoundary UpperBoundary $6;
 LowerBoundary="&LowerBoundary";
 UpperBoundary="&UpperBoundary";
 LowerBoundary_=TRANWRD(LowerBoundary,".","_");
 UpperBoundary_=TRANWRD(UpperBoundary,".","_");
 call symput('LowerBoundary_NoDot',strip(LowerBoundary_));
 call symput('UpperBoundary_NoDot',strip(UpperBoundary_));
run;
 
proc univariate data=&EM_IMPORT_DATA noprint;
      var %EM_INTERVAL_INPUT ;
      output out=userdata.Pctls 
                       pctlpts  =  0   &LowerBoundary         &UpperBoundary         100 
                       pctlpre  = %EM_INTERVAL_INPUT 
                       pctlname = _0  _&LowerBoundary_NoDot  _&UpperBoundary_NoDot  _100;
run;

%MACRO varnamelist(dsn);
%global varlist;
%let dsid=%sysfunc(open(&dsn,i));
%let varlist=;
%do i=1 %to %sysfunc(attrn(&dsid,nvars));
   %let varlist=&varlist %sysfunc(varname(&dsid,&i));
%end;
%let rc=%sysfunc(close(&dsid));
%put varlist=&varlist;
%mend varnamelist;

%varnamelist(userdata.Pctls)
title;

data userdata.extreme_percentiles
		(keep=name Pctl_0 Pctl_&LowerBoundary_NoDot Pctl_&UpperBoundary_NoDot Pctl_100);
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
 
proc print data=userdata.extreme_percentiles;
run;

			/*** Add Score Code ***/

%macro scorecode(file);
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
%mend scorecode;

%scorecode(&EM_FILE_EMFLOWSCORECODE);
%scorecode(&EM_FILE_EMPUBLISHSCORECODE);
/* end of program */
