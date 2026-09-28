/* Specify the name for the output file. */
%let name=barChartIndSTP;

/* Set output options. */
goptions reset=all;
goptions device=gif;

/* Set colors for indicator features. */
%let gray=gray;
%let crefgray=graycc;
%let backcolor=grayee;

/* Set colors and patterns for the bars. */
%let green=cxC2E699;
%let pink=cxFA9FB5;
%let red=cxFF0000;

pattern1 v=s c=&green; 
pattern2 v=s c=&red; 
pattern3 v=s c=&pink; 

/* Define fonts for indicator title and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/**************************************************************************/
/* The do_chart macro creates an individual bar chart indicator with a 
target value marker.

The do_chart macro accepts the following list of parameters:

data_name = name of the data set that contains indicator values
pltname = name of GRSEG to store the graph
*/

%macro do_chart(data_name, pltname);

%local data_name pltname;

/* Extract values from the data set into macro variables. */
proc sql noprint;
   select unique title_text into :title_text from &data_name;
   select unique value_format into :value_format from &data_name;
   select unique y_max into :y_max from &data_name;
   select unique y_by into :y_by from &data_name;
quit;     

/* Trim blank spaces from the macro variable values. */
%let title_text=%trim(&title_text);
%let value_format=%trim(&value_format);
%let y_max=%trim(&y_max);
%let y_by=%trim(&y_by);

data temp_data; set &data_name;
   format actual &value_format;
   
   /* Evaluate the actual value as a percent of the target value and assign colors. */
   length evaluation $12;
   percent_of_target=actual/target;
   if (percent_of_target < poor_pct) then evaluation='Poor';
   else if (percent_of_target < good_pct) then evaluation='Satisfactory';
   else evaluation='Good';
   
   /* Set the 'tool tip' for the chart to provide a link to an 
      HTML page with drill-down details. */
   length htmlvar $200;
   htmlvar='title='||quote(
   'Quarter: '|| trim(left(quarter)) ||'0D'x||
   'Target: '|| trim(left(put(target,&value_format))) ||'0D'x||
   'Actual: '|| trim(left(put(actual,&value_format))) ||'0D'x||
   'Actual as Percent of Target: '|| trim(left(put(percent_of_target,percent6.0)))
   ) || ' '|| 
   'href="'||"&hardcoded_drilldown"||'"';
run;

/* Annotate a custom target marker for each bar. */
data target_anno; set temp_data;
   length function $ 8 style $ 20 color $ 12;
   hsys='3'; when='a'; position='5'; 
   
   /* Draw the triangular pointer (using character 'A' of the MARKER 
      software font provided with SAS/GRAPH software). */
   function='label'; style='marker'; text='A'; 
   if (evaluation eq 'Good') then color="&green"; 
   else if (evaluation eq 'Poor') then color="&red";
   else if (evaluation eq 'Satisfactory') then color="&pink";
   else color='white';
   xsys='2'; ysys='2'; midpoint=quarter; y=target; size=.01;
   output;
   xsys='7'; x=9; size=4;
   output;
   
   /* Draw an outline around the triangle using the MARKERE font
      (empty/outline of the triangle marker). */
   style='markere'; color="&gray";
   xsys='2'; ysys='2'; midpoint=quarter; y=target; size=.01;
   output;
   
   /* Reposition the cursor and draw a line from the point of the 
      triangle, across the bar. */
   xsys='7'; x=9; size=4;
   output;
   hsys='3'; position='5'; xsys='2'; ysys='2'; hsys='3'; position='5'; size=1; color="&gray";
   function='move'; midpoint=quarter; y=target;
   output;
   function='draw'; xsys='7'; x=6;
   output;
   function='draw'; xsys='7'; x=-12;
   output;
run;

/* Add dummy data values to guarantee that all three possible 
   colors are accounted for, so that poor is always red, 
   satisfactory is always pink, and good is always green.  Otherwise
   the colors will be assigned in alphabetic order, and if the particular
   graph is missing any of the three categories then that will affect which
   color goes to which category. */
data levels_guarantee;
   length evaluation $12;
   quarter='Q1'; evaluation="Poor";
   output;
   quarter='Q1'; evaluation="Satisfactory";
   output;
   quarter='Q1'; evaluation="Good";
   output;
run;

data temp_data; 
   set temp_data levels_guarantee;
run;

/* Draw the chart and save it with the specified name so it can later be 
   replayed into the desired location of a dashboard.  */
goptions gunit=pct htitle=10 ftitle=&ftitle htext=8.0 ftext=&ftext;
goptions xpixels=275 ypixels=200;

axis1 label=none order=(0 to &y_max by &y_by) minor=none major=(h=2) offset=(0,0);
axis2 label=none offset=(8,10);

title "&title_text";
proc gchart data=temp_data anno=target_anno;
   vbar quarter / discrete 
      type=sum
      sumvar=actual 
      subgroup=evaluation 
      raxis=axis1
      maxis=axis2
      autoref cref=&crefgray clipref
      coutline=&gray
      width=7
      space=7
      nolegend
      html=htmlvar
      des=""
      name="&pltname";
run;
quit;

%mend do_chart;

/**************************************************************************/

/* Create an example data set with the variables required by the 
   do_chart macro. */
data data1;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Market Share         Q1   .23    .24   percentn6.0   .65 .90    .30    .10
Market Share         Q2   .20    .25   percentn6.0   .65 .90    .30    .10
Market Share         Q3   .19    .26   percentn6.0   .65 .90    .30    .10
Market Share         Q4   .17    .27   percentn6.0   .65 .90    .30    .10
;
run;

goptions border;

%let _GOPT_DEVICE=gif;
%let _ODSOPTIONS=gtitle gfootnote style=minimal;
%stpbegin;

/* Call the macro  with specified data values to draw a bar chart indicator. */
%do_chart(data1,market1);

%stpend;
