/***************************************************************/
/*                                                             */
/*            S A S   S A M P L E   L I B R A R Y              */
/*                                                             */
/*    NAME: lpsole02                                             */
/*   TITLE: Reoptimizing Using BASIS=WARMSTART (lpsole02)        */
/* PRODUCT: OR                                                 */
/*  SYSTEM: ALL                                                */
/*    KEYS: OR                                                 */
/*   PROCS: OPTMODEL                                           */
/*    DATA:                                                    */
/*                                                             */
/* SUPPORT:                             UPDATE:                */
/*     REF:                                                    */
/*    MISC: Example 2 from the Linear Programming Solver       */
/*          chapter of Mathematical Programming.               */
/*                                                             */
/***************************************************************/


data fooddata;
   infile datalines;
   input name $  cost  prot  fat  carb  cal;
   datalines;
Bread   2     4     1    15    90
Milk    3.5   8     5    11.7  120
Cheese  8     7     9    0.4   106
Potato  1.5   1.3   0.1  22.6  97
Fish    11    8     7    0     130
Yogurt  1     9.2   1    17    180
;

cas sascas1;

proc cas; setsessopt/metrics=true; run; quit;

libname mycaslib cas sessref=sascas1;

proc optmodel sessref=sascas1;
   /* declare index set */
   set<str> FOOD;

   /* declare variables */
   var diet{FOOD} >= 0;

   /* objective function */
   num cost{FOOD};
   min f=sum{i in FOOD}cost[i]*diet[i];

   /* constraints */
   num prot{FOOD};
   num fat{FOOD};
   num carb{FOOD};
   num cal{FOOD};
   num min_cal, max_prot, min_carb, min_fat;
   con cal_con: sum{i in FOOD}cal[i]*diet[i] >= 300;
   con prot_con: sum{i in FOOD}prot[i]*diet[i] <= 10;
   con carb_con: sum{i in FOOD}carb[i]*diet[i] >= 10;
   con fat_con: sum{i in FOOD}fat[i]*diet[i] >= 8;

   /* read parameters */
   read data fooddata into FOOD=[name] cost prot fat carb cal;

   /* bounds on variables */
   diet['Fish'].lb = 0.5;
   diet['Milk'].ub = 1.0;

   /* solve original problem */
   solve with lp;
   print diet;

   /*  Modified Objective Function  */
   cost['Cheese']=10; cost['Fish']=7;
   solve with lp/presolver=none
              basis=warmstart
              algorithm=ps
              logfreq=1;
   print diet;


   /*  Modified RHS  */
   cost['Cheese']=8; cost['Fish']=11;cal_con.lb=150;
   solve with lp/presolver=none
                 basis=warmstart
                 algorithm=ds
                 logfreq=1;
   print diet;


   /*  Adding a New Constraint  */
   cal_con.lb=300;
   num sod{FOOD}=[148 122 337 186 56 132];
   con sodium: sum{i in FOOD}sod[i]*diet[i] <= 550;
   solve with lp/presolver=none
                 basis=warmstart
                 logfreq=1;
   print diet;
quit;


