proc printto log="c:\temp\ws.log";

*ProcessBody;
%global custage custsex credit_limit;

%put >>**********************************;
%put custage=&custage;
%put custsex=&custsex;

data _null_;

                /* Regel 1: das Kreditlimit hängt vom Alter ab, HJE */
                if &custage. < 18 then do;
                               creditLimit = 0;
                end; else if &custage. <= 25 then do;
                               creditLimit = 2000000;
                end; else if &custage. <= 45 then do;
                               creditLimit = 1000000;
                end; else do;
                               creditLimit = 5000;
                end;

                /* Regel 2: das Kreditlimit hängt vom Geschlecht ab */
                if upcase("&custsex.") = "F" and creditlimit > 0 then do;
                               creditLimit = creditlimit + 2000;
                end;
                
                /* Rückgabevariable */
                call symput("credit_limit",creditLimit);
                
run;

%put **********************************<<;
%put custage=&custage;
%put custsex=&custsex;
%put credit_limit=&credit_limit.;

proc printto;run;
