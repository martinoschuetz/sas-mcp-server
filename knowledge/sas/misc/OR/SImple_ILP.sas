libname mycaslib cas caslib=casuser;

/* Problem data */
data mycaslib.ex1data;
   input _id_ field1 $ field2 $ field3 $ field4 field5 $ field6;
   datalines;
1  NAME       .             ex1data           .     .                 .
2  ROWS       .             .                 .     .                 .
3  MAX        z             .                 .     .                 .
4  L          volume_con    .                 .     .                 .
5  L          weight_con    .                 .     .                 .
6  COLUMNS    .             .                 .     .                 .
7  .          .MRK0         'MARKER'          .     'INTORG'          .
8  .          x[1]          z                 1     volume_con       10
9  .          x[1]          weight_con       12     .                 .
10 .          x[2]          z                 2     volume_con      300
11 .          x[2]          weight_con       15     .                 .
12 .          x[3]          z                 3     volume_con      250
13 .          x[3]          weight_con       72     .                 .
14 .          x[4]          z                 4     volume_con      610
15 .          x[4]          weight_con      100     .                 .
16 .          x[5]          z                 5     volume_con      500
17 .          x[5]          weight_con      223     .                 .
18 .          x[6]          z                 6     volume_con      120
19 .          x[6]          weight_con       16     .                 .
20 .          x[7]          z                 7     volume_con       45
21 .          x[7]          weight_con       73     .                 .
22 .          x[8]          z                 8     volume_con      100
23 .          x[8]          weight_con       12     .                 .
24 .          x[9]          z                 9     volume_con      200
25 .          x[9]          weight_con      200     .                 .
26 .          x[10]         z                10     volume_con       61
27 .          x[10]         weight_con      110     .                 .
28 .          .MRK1         'MARKER'          .     'INTEND'          .
29 RHS        .             .                 .     .                 .
30 .          .RHS.         volume_con     1000     .                 .
31 .          .RHS.         weight_con      500     .                 .
32 BOUNDS     .             .                 .     .                 .
33 UP         .BOUNDS.      x[1]              4     .                 .
34 UP         .BOUNDS.      x[2]              4     .                 .
35 UP         .BOUNDS.      x[3]              4     .                 .
36 UP         .BOUNDS.      x[4]              4     .                 .
37 UP         .BOUNDS.      x[5]              4     .                 .
38 UP         .BOUNDS.      x[6]              4     .                 .
39 UP         .BOUNDS.      x[7]              4     .                 .
40 UP         .BOUNDS.      x[8]              4     .                 .
41 UP         .BOUNDS.      x[9]              4     .                 .
42 UP         .BOUNDS.      x[10]             4     .                 .
43 ENDATA     .             .                 .     .                 .
;

/* Solve with PROC OPTMILP */
proc optmilp data=mycaslib.ex1data primalout=mycaslib.ex1soln;
run;

title "Example 1 Solution Data";
proc print data=mycaslib.ex1soln noobs label;
run;

/* Solve with PROC CAS */
proc cas;
   loadactionset "optimization";
   action optimization.solveMilp result=r status=s /
      data      = {name = "ex1data"}
      primalOut = {name = "ex1soln" replace = true};
   run;
   print r.ProblemSummary; run;
   print r.SolutionSummary; run;
   action table.fetch / table = "ex1soln"; run;
quit;