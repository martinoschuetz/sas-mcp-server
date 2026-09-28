*ProcessBody;

%STPBEGIN;

OPTIONS VALIDVARNAME=ANY;

PROC SQL;
   CREATE TABLE WORK.QUERY_FOR_CLASS_0000 AS 
   SELECT t1.Name, 
          t1.Sex, 
          t1.Age, 
          t1.Height, 
          t1.Weight
      FROM sashelp.CLASS t1;
QUIT;
/* --- End of code for "Query Builder1". --- */

/* --- Start of code for "JMP Stored Process Packager". --- */
libname jmppkg "&_STPWORK";
filename stpwork "&_STPWORK";


proc copy in=WORK out=jmppkg;
   select QUERY_FOR_CLASS_0000;
run;

proc datasets nodetails nolist library=jmppkg;
   change QUERY_FOR_CLASS_0000=QUERY_FOR_CLASS_0000;
run; quit;

%STPEND;
