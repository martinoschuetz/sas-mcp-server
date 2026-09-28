%MACRO DUMMY(in_data=&dat, out_data=aus, pref=V, length=3,
             replace=Y, full=N, varlist=&varlist);
/********************************************************************
Disclaimer:  I am not the original author of this very useful & handy
code. Unfortunately, the author's name was deleted when the text was
edited & augmented. So thanks to the unknown programmer!


When do I use this macro?
        Whenever you want to create sets of Dummy-Variables (a.k.a Indicator-, or 0/1-Variables) 
			 based on either numerical or character variables.  This comes very handy
        for some statistical procedures, which do not support a CLASS statement
        (e.g. PROC REG, PROC LOGISTIC, etc.).

What kind of variables can I use?
        Since the original variables are treated as categorical variables they
        should have either a restricted number of categories or they should be
        mapped by a format to a restricted number of categories.
        Numerical variables should be positive integers (otherwise use formats).
        Remember, if you have k categories for your original variables,you will
        get k-1 (or if you want, k) numerical Dummy-Variables.

What happens to missing values?
        unfortunately, 'missing' is NOT treated as a category. You have to replace
        missings before using the macro.  Otherwise you will lose the entire
        observation, if there is one of the variables missing.  (see example below).

What do the parameters of the macro mean?
        in_data = Input-data set
        out_dat = Output-data set (recommended: in_data^=out_dat)
        pref    = Prefix for Dummy-Variables (should be short)
                  Name of the dummy-variable will be 'Prefix''# of variable'_'category' 
			      truncated to 8 chars.
        length  = internal length of the numerical dummy-variables
        replace = if ==Y, the original variable will not be in the Output-Data-Set.
        full    = if ==Y, k dummy-vs. will be created for k categories. Default is
                  N, i.e., k-1 dummy-vs. will be created (which suffices for all
                  statistical procedures).
        varlist = list of variables which should be transformed. Be sure that all
                  variables are on the input-data-set and that there are no
                  missspelinks.

What is the secret of this macro, which makes it so tricky?
        The macro is so fast, because the transformation of the variables is not
        done within a data step.  Instead, PROC GLMMOD is (mis)used.

Are there any known bugs?
        There might be problems with the generated variable-names (it is hard to
        create unique names using just 8 characters).
        Do not use special characters (e.g., '<','-','.') in your format.
        If you happen to find other problems, please contact me. (na221@fen.baynet.de)



************************************************************/

%local i;
%local maxloop;
%let maxloop=1000; /* to avoid infinite looping */
%let i=0;  /* safe loop to determine variable names and number of
variables */

%local eol;
%let eol=0;
%global anzvar;
%let anzvar=0;
%do %while( not(&eol) and &i<&maxloop );
     %let i=%eval(&i+1);
     %local var&i;
     %let var&i=%scan(&varlist,&i);
     %if &&var&i= %then %do;
          %let eol=1;  /* end of list found */
          %let anzvar=%eval(&i-1);
          %put MACROGEN(DUMMY): NOTE: &anzvar variable names read from
variable list;
     %end;
     %else %put MACROGEN(DUMMY): NOTE: var&i=&&var&i;
%end;

data __bb;
      length __var $8 ;
      %do i=1 %to &anzvar;
           __var="&&var&i";
      output;
      %end;
*proc print data=__bb;
 run;

* proc contents data=&in_data noprint
*       out=__cc;
* proc print data=__cc;

%DO J=1 %TO &ANZVAR;
data __aa;
    set &in_data;
    __obbs=_N_;
 /* Check, whether variables are on data set */


PROC GLMMOD DATA=__aa OUTDESIGN=OUT&J
                               OUTPARM=PARM NOPRINT;
   CLASS &&VAR&J;
   MODEL __obbs= &&VAR&J / NOINT;

%global anz_&j;

DATA _NULL_;
   SET PARM NOBS=ANZ;
   CALL SYMPUT ('ANZ_'||trim(left("&j")),TRIM(LEFT(ANZ)));
 run;

%do i=1 %to &&anz_&j;
        %global lab&j._&i;
        %global col&j._&i;
%end;

DATA _NULL_;
   SET PARM ;
   CALL SYMPUT ('LAB'||"&j._"||TRIM(LEFT(_COLNUM_)),
        "&&VAR&J="!!TRIM(LEFT(&&VAR&J))||"? 1:0");
   CALL SYMPUT ('COL'||"&j._"||TRIM(LEFT(_COLNUM_)),
        substr("&pref"||"&J._"!!TRIM(LEFT(&&VAR&J)),1,8)  );
 run;

DATA OUT&J;
   SET OUT&J (RENAME=(
                   %DO I=1 %TO &&ANZ_&j;
                         COL&I=&&COL&j._&I
                    %END;
                     )
              );
    Label  %DO I=1 %TO &&ANZ_&j;
              &&COL&j._&I="&&lab&j._&i"
           %END;
        ;
    LenGTH  %DO I=1 %TO &&anz_&j;
              &&COL&j._&I
           %END;
           &length..;

 %if &full^=Y %then %do;  /* do not overparameterize */
          %*put MACROGEN(DUMMY): NOTE: &&anz_&j -1
         dummy-variables are created for &&var&j;
          %let anz_&j=%eval(&&anz_&j-1);
          %put MACROGEN(DUMMY): NOTE: &&anz_&j
         dummy-variables are created for &&var&j;
    DATA OUT&J;
       SET OUT&J (keep= __obbs
                 %do i=1 %to &&anz_&j;
                    &&col&j._&i
                  %end;
              );
 %end; /* if full^=Y .. */

   %DO I=1 %TO &&anz_&j;
    %put MACROGEN(DUMMY): NOTE: Variable &&COL&j._&I : &&LAB&j._&I;
   %END;

   %if &full^=Y %then %do;  /* do not overparameterize */
       %local ___a;
       %let ___a=%eval(&&anz_&j+1);
      %put MACROGEN(DUMMY): NOTE: Variable
&&COL&j._&___a dropped: &&LAB&j._&___a is default;
   %end;


RUN;
%END;
*options notes ;

DATA &out_data (DROP=__FEHL __STERN __TEXT __TEXT2 __obbs);
   MERGE __aa (IN=IN0
                 %if &replace=Y %then %do;
                 /* drop original variables */
                         DROP= %DO J=1 %TO &ANZVAR;
                                   &&VAR&J
                                %END;
                  %end;
                )
      %DO J=1 %TO &ANZVAR;
         OUT&J (IN=IN&J)
      %END;
      ;
   BY __obbs;
   IF IN0 %DO J=1 %TO &ANZVAR; *IN&J %END; =0 THEN DO;
      FILE PRINT;
      __FEHL='*** ACHTUNG: FEHLER! *** ACHTUNG: FEHLER! ***';
      __STERN='*********************************************';
      __TEXT=  '*** BEIM MERGE WURDEN NICHT ALLE SAETZE   ***';
      __TEXT2= '*** GEFUNDEN!                             ***';
PUT @10 __STERN / @10 __FEHL / @10 __TEXT / @10 __TEXT2 / @10 __STERN;
      STOP;
   END;
RUN;


%MEND;


/*********************************************************************/
/* Example                                                           */
/*********************************************************************/

dm 'clear out; clear log';

options mprint nosymbolgen nomlogic;

proc format ;
        value bb 0-3     ='Low'
                3<-high ='High'
                -1      ='missing';
        value ee 1-<2    ='1'
                2-<3    ='2'
                3-<4    ='3'
                other   ='4'
                ;


data beispiel;
        format  a 3. b bb. c 1. d $1. e ee.;
        infile cards;
        input  a  b  c  d $ e ;
        if b=. then b=-1;
        cards;
111  2 3 A 1.1
121  3 4 B 2.1
132  4 0 C 4.1
145  4 0 C 4.1
165  - 4 C 3.1
        ;


proc print data=beispiel;
 run;

%DUMMY(in_data=beispiel, out_data=aus, pref=V, length=3,
             replace=N, full=Y, varlist= b e d);

proc print data=aus labels;
title  ' b e d -> Dummy variables (full replacement)';
run;

%DUMMY(in_data=beispiel, out_data=aus, pref=V, length=3,
             replace=N, full=N, varlist= b e d);

proc print data=aus labels;
title  ' b e d -> Dummy variables (sufficient replacemnt)';

run;
