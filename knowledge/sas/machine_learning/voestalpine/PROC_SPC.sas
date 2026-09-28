/* start a CAS session and assign the libnames */
options cashost="172.28.235.22" casport=5570;

cas mysess;
caslib _all_ assign;

/* Example 15.2 Applying Tests for Special Causes */

data casuser.Random;
   length processname $16 subgroupname $16;
   do i = 1 to 100;
      processname  = 'Process'  || left( put( i, 8. ) );
      subgroupname = 'Subgroup' || left( put( i, 8. ) );
      do subgroup = 1 to 30;
         do j = 1 to 5;
            process = rannor(123);
            output;
         end;
      end;
   end;
   drop i j;
run;

proc spc data=casuser.Random;
   xchart / /*exchart*/
            tests    = 1 to 8
            outtable = casuser.RandomTests
            outlimits = casuser.AllLimits;
run;

/* Example 15.3 Producing Charts with PROC SHEWHART */

data Process47Tests;
   set casuser.RandomTests(where=(_VAR_ eq 'Process47'));
run;

proc shewhart table=Process47Tests;
   xchart Process47 * Subgroup /
            tests = 1 to 8
            markers;
run;


cas mysess terminate;