libname mycas cas caslib=casuser;

/************************************************************************/
/*                                                                      */
/*          S A S   S A M P L E   L I B R A R Y                         */
/*                                                                      */
/*    NAME: onete04                                                     */
/*   TITLE: Minimum Spanning Tree for Computer Network Design (onete04) */
/* PRODUCT: OR                                                          */
/*  SYSTEM: ALL                                                         */
/*    KEYS: Minimum spanning tree                                       */
/*   PROCS: OPTNETWORK, PRINT                                           */
/*    DATA:                                                             */
/*                                                                      */
/* SUPPORT:                             UPDATE:                         */
/*     REF:                                                             */
/*    MISC: Example 4 from the OPTNETWORK documentation.                */
/*                                                                      */
/************************************************************************/

/* Computer Network Connectivity Data */

data mycas.LinkSetInCompNet;
   input from $ to $ weight @@;
   datalines;
A B 1.0  A C 1.0  A D 1.5  B C 2.0  B D 4.0
B E 3.0  C D 3.0  C F 3.0  C H 4.0  D E 1.5
D F 3.0  D G 4.0  E F 1.0  E G 1.0  F G 2.0
F H 4.0  H I 1.0  I J 1.0
;

/* Find a Minimum Spanning Tree */

proc optnetwork
   links      = mycas.LinkSetInCompNet;
   minSpanTree
      out     = mycas.MinSpanTree;
run;

title 'Minimum Spanning Tree';
proc print data=mycas.MinSpanTree noobs label;
   sum weight;
run;

title;
