/*---------------------------------------------------------------
 * Name:         List n extreme rows per series
 * Description:  Lists the n lowest and highest values of 
 *               the series, using PROC UNIVARIATE  
 *               (Note: Requires SAS/STAT license to run!).
 *---------------------------------------------------------------
 * Scope:        Node
 * Content:      Extreme Values
 * Organization: None
 * Presentation: Table
 *---------------------------------------------------------------
 * Parameters:  
 * FS_MaxRows   - Maximum number of rows to display. 
 *--------------------------------------------------------------*/


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
/*- Augment with weekday for appropriate time intervals   -*/
/*---------------------------------------------------------*/

%global weekdayflag;
%macro checkinterval;
  %if &HPF_INTERVAL=DAY OR %substr(&HPF_INTERVAL,1,7)=WEEKDAY %then %do;
   data temp;
     set temp;
	 x=weekday(&HPF_TIMEID);
     if x=1 then day_of_week='Sun';
     else if x=2 then day_of_week='Mon';
     else if x=3 then day_of_week='Tue';
     else if x=4 then day_of_week='Wed';
     else if x=5 then day_of_week='Thu';
     else if x=6 then day_of_week='Fri';
     else if x=7 then day_of_week='Sat';
     label day_of_week="Day of Week";
	run;
    %let weekdayflag=day_of_week; 
   %end;
   %else %let weekdayflag=;
%mend;
%checkinterval;



/*---------------------------------------------------------*/
/*- set the title                                         -*/
/*---------------------------------------------------------*/
title1 "List Extreme Values for Dependent Variable: &HPF_DEPVAR1";


/*---------------------------------------------------------*/
/*- List Extreme Values                                   -*/
/*---------------------------------------------------------*/
ods select ExtremeObs;
PROC UNIVARIATE DATA = temp NEXTROBS=&FS_MAXROWS;
    VAR &HPF_DEPVAR1;
	ID &HPF_TIMEID &weekdayflag;
	HISTOGRAM / NOPLOT ;
run;

title1;



%stpend;
