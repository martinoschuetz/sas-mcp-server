libname mycaslib cas caslib=casuser;

/*****************************************************************************/
/*                                                                           */
/*          S A S   S A M P L E   L I B R A R Y                              */
/*                                                                           */
/*    NAME: onete09                                                          */
/*   TITLE: Shortest Path in a Road Network by Date and Time (onete09)       */
/* PRODUCT: OR                                                               */
/*  SYSTEM: ALL                                                              */
/*    KEYS: Shortest paths, By-Group                                         */
/*   PROCS: OPTNETWORK, PRINT                                                */
/*    DATA:                                                                  */
/*                                                                           */
/* SUPPORT:                             UPDATE:                              */
/*     REF:                                                                  */
/*    MISC: Example 9 from the OPTNETWORK documentation.                     */
/*                                                                           */
/******************************************************************************/

data mycaslib.LinkSetInRoadNC;
   input start_inter $1-20 end_inter $20-40 miles miles_per_hour
      date date11. time time10.;
   format date date11. time time10.;
   time_to_travel = miles * 1/miles_per_hour * 60;
   datalines;
614CapitalBlvd      Capital/WadeAve      0.6  25 15-APR-2013 10:30 am
614CapitalBlvd      Capital/US70W        0.6  25 15-APR-2013 10:30 am
614CapitalBlvd      Capital/US440W       3.0  45 15-APR-2013 10:30 am
Capital/WadeAve     WadeAve/RaleighExpy  3.0  40 15-APR-2013 10:30 am
Capital/US70W       US70W/US440W         3.2  60 15-APR-2013 10:30 am
US70W/US440W        US440W/RaleighExpy   2.7  60 15-APR-2013 10:30 am
Capital/US440W      US440W/RaleighExpy   6.7  60 15-APR-2013 10:30 am
US440W/RaleighExpy  RaleighExpy/US40W    3.0  60 15-APR-2013 10:30 am
WadeAve/RaleighExpy RaleighExpy/US40W    3.0  60 15-APR-2013 10:30 am
RaleighExpy/US40W   US40W/HarrisonAve    1.3  55 15-APR-2013 10:30 am
US40W/HarrisonAve   SASCampusDrive       0.5  25 15-APR-2013 10:30 am
614CapitalBlvd      Capital/WadeAve      0.6  25 16-APR-2013  9:30 am
614CapitalBlvd      Capital/US70W        0.6  25 16-APR-2013  9:30 am
614CapitalBlvd      Capital/US440W       3.0  45 16-APR-2013  9:30 am
Capital/WadeAve     WadeAve/RaleighExpy  3.0  25 16-APR-2013  9:30 am
Capital/US70W       US70W/US440W         3.2  60 16-APR-2013  9:30 am
US70W/US440W        US440W/RaleighExpy   2.7  60 16-APR-2013  9:30 am
Capital/US440W      US440W/RaleighExpy   6.7  60 16-APR-2013  9:30 am
US440W/RaleighExpy  RaleighExpy/US40W    3.0  60 16-APR-2013  9:30 am
WadeAve/RaleighExpy RaleighExpy/US40W    3.0  60 16-APR-2013  9:30 am
RaleighExpy/US40W   US40W/HarrisonAve    1.3  55 16-APR-2013  9:30 am
US40W/HarrisonAve   SASCampusDrive       0.5  25 16-APR-2013  9:30 am
614CapitalBlvd      Capital/WadeAve      0.6  25 18-APR-2013  8:30 am
614CapitalBlvd      Capital/US440W       3.0  45 18-APR-2013  8:30 am
Capital/WadeAve     WadeAve/RaleighExpy  3.0  25 18-APR-2013  8:30 am
Capital/US440W      US440W/RaleighExpy   6.7  60 18-APR-2013  8:30 am
US440W/RaleighExpy  RaleighExpy/US40W    3.0  60 18-APR-2013  8:30 am
WadeAve/RaleighExpy RaleighExpy/US40W    3.0  60 18-APR-2013  8:30 am
RaleighExpy/US40W   US40W/HarrisonAve    1.3  55 18-APR-2013  8:30 am
US40W/HarrisonAve   SASCampusDrive       0.5  25 18-APR-2013  8:30 am
;

proc optnetwork
   links         = mycaslib.LinkSetInRoadNC;
   linksVar
      from       = start_inter
      to         = end_inter
      weight     = time_to_travel;
   shortestPath
      outPaths   = mycaslib.ShortPathP
      outWeights = mycaslib.ShortPathW
      source     = "614CapitalBlvd"
      sink       = "SASCampusDrive";
   displayout
      ProblemSummary  = ProblemSummary
      SolutionSummary = SolutionSummary;
   by date time;
run;
%put &_OROPTNETWORK_;

data ShortPathW;
   set mycaslib.ShortPathW;
run;
proc sort data=ShortPathW;
   by date time;
run;

/* Print Summary Information */

title 'Summary Information on Shortest Paths';
proc print data=ShortPathW noobs label;
run;

data ShortPathP;
   set mycaslib.ShortPathP;
run;
proc sort data=ShortPathP;
   by date time order;
run;

/* Print Details of the Shortest Paths */

title 'Details on Shortest Paths by Date and Time';
proc print data=ShortPathP(keep=order start_inter end_inter time_to_travel date time) noobs label;
   sum time_to_travel;
   by date time;
run;

