/*---------------------------------------------------------------
 * Name:         Unit Root Tests
 * Description:  Displays results of unit root tests.
 *---------------------------------------------------------------
 * Scope:        Node
 * Content:      Unit Root Tests
 * Organization: None
 * Presentation: Table
 *---------------------------------------------------------------
 
*/
*ProcessBody;
%stpbegin;



/*---------------------------------------------------------*/
/*- include the LIBNAME statements for the project        -*/
/*---------------------------------------------------------*/
%include "&HPF_INCLUDE";

/*----------------------------------------------------------*/
/*- determine the DATA= and OUT= data set for the selected level -*/
/*----------------------------------------------------------*/
%let level    = %eval(&HPF_CURRENT_LEVEL);
%let dataset = %str(&&HPF_LEVEL_LIBNAME&level...data);

/*----------------------------------------------------------*/
/*- determine the BY variables for the selected level      -*/
/*----------------------------------------------------------*/
%let byvars = %str(&&HPF_LEVEL_BYVARS&level..);

/*----------------------------------------------------------*/
/*- determine the WHERE clause for the selected node       -*/
/*----------------------------------------------------------*/
%let where = %unquote(&&HPF_LEVEL_DATAWHERE&level);

/*----------------------------------------------------------*/
/*- determine the HORIZON for the selected node            -*/
/*----------------------------------------------------------*/
%let horizon = %unquote(&HPF_CURRENT_HORIZON);

/*---------------------------------------------------------*/
/*- subset the input data set to get the selected node    -*/
/*---------------------------------------------------------*/
data temp; 
set &dataset;
&where;
run;

/*---------------------------------------------------------*/
/*- set the title                                         -*/
/*---------------------------------------------------------*/
title1 "Unit Root Tests for Dependent Variable: &HPF_DEPVAR1";


/*---------------------------------------------------------*/
/*- Run Unit Root Tests                                   -*/
/*---------------------------------------------------------*/

proc sort data=temp;
  by &byvars &HPF_TIMEID;
run;

proc hpfdiag data=temp print=all;
  id &HPF_TIMEID interval=&HPF_INTERVAL;
  forecast &HPF_DEPVAR1;
  arimax;
  trend diff=auto sdiff=auto ;

 ODS SELECT Hpfdiag.Variable.StationarityTest.DFTestSummary 
               Hpfdiag.Variable.StationarityTest.SeasonDFTestSummary 
               Hpfdiag.Variable.StationarityTest.JointTestSummary
               Hpfdiag.Variable.StationarityTest.DFTestSummary
               Hpfdiag.Variable.StationarityTest.DFTest
               Hpfdiag.Variable.StationarityTest.JointTest;

run; 
title1;



%stpend;
