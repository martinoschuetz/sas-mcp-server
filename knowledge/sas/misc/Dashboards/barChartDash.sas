/* Specify the name for the output file. */
%let name=barChartDash;

/* Set output options. */
filename odsout '.';
goptions reset=all;
goptions device=gif;

%let title1=Sales Dashboard;
%let title2=(All currency in US $);
%let title3=19dec2004;

/* Set colors for indicator features. */
%let gray=gray;
%let crefgray=graycc;
%let backcolor=grayee;

/* Set colors and patterns for the bars. */
%let green=cxc2e699;
%let pink=cxfa9fb5;
%let red=cxff0000;

pattern1 v=s c=&green; 
pattern2 v=s c=&red; 
pattern3 v=s c=&pink; 

/* Define fonts for indicator and dashboard titles and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Create a user-defined format that prints 200000 as $200k. */
proc format;
   picture kdollar low-high='0009k ' (prefix='$' mult=.001);
run;

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
/* Delete all GRSEGs in the current session to ensure that indicators use
the expected names.  If a name is already in use, then an attempt to create
a new GRSEG using that name it will add a number to the name.  In that case, 
the subsequent GREPLAY will be placing the wrong GRSEGs into the dashboard.

Note: The macro code just checks whether there are any gsegs to delete.  If 
it tried to delete specific entries and none existed, then you would get an
error message: "ERROR: Member-name GSEG is unknown." */

%macro delcat(catname);
 %if %sysfunc(cexist(&catname)) %then %do;
  proc greplay nofs igout=&catname;
  delete _all_;
  run;
 %end;
 quit;
%mend delcat;

%delcat(work.gseg);

/*******************************************************************************/
/*  Create a separate data set for each chart. */

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


data data2;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Order Size           Q1   405    400   comma7.0  .50 .75    500    100
Order Size           Q2   421    410   comma7.0  .50 .75    500    100
Order Size           Q3   435    420   comma7.0  .50 .75    500    100
Order Size           Q4   449    430   comma7.0  .50 .75    500    100
;
run;


data data3;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
New Customers        Q1   346    300   comma7.0  .50 .85    500    100
New Customers        Q2   430    350   comma7.0  .50 .85    500    100
New Customers        Q3   447    400   comma7.0  .50 .85    500    100
New Customers        Q4   468    450   comma7.0  .50 .85    500    100
;
run;


data data4;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
On Time Delivery     Q1   .83    .92    percentn6.0   .60 .90    1.0    .25
On Time Delivery     Q2   .73    .93    percentn6.0   .60 .90    1.0    .25
On Time Delivery     Q3   .65    .94    percentn6.0   .60 .90    1.0    .25
On Time Delivery     Q4   .68    .95    percentn6.0   .60 .90    1.0    .25
;
run;


data data5;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Satisfaction         Q1   3.2    3.3    comma5.1      .60 .90    5    1
Satisfaction         Q2   3.0    3.3    comma5.1      .60 .90    5    1
Satisfaction         Q3   2.8    3.3    comma5.1      .60 .90    5    1
Satisfaction         Q4   2.7    3.3    comma5.1      .60 .90    5    1
;
run;


data data6;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Chardonnay           Q1    68634    69000    kdollar.      .60 .90    125000    25000
Chardonnay           Q2    64025    76820    kdollar.      .60 .90    125000    25000
Chardonnay           Q3   104063    84640    kdollar.      .60 .90    125000    25000
Chardonnay           Q4   107610    98900    kdollar.      .60 .90    125000    25000
;
run;

data data7;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Cabernet             Q1    28430    27000    kdollar.      .60 .90    125000    25000
Cabernet             Q2    30228    30060    kdollar.      .60 .90    125000    25000
Cabernet             Q3    35053    33120    kdollar.      .60 .90    125000    25000
Cabernet             Q4    38728    38700    kdollar.      .60 .90    125000    25000
;
run;

data data8;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Merlot               Q1    25440    25500    kdollar.      .60 .90    125000    25000
Merlot               Q2    24977    28390    kdollar.      .60 .90    125000    25000
Merlot               Q3    28955    31280    kdollar.      .60 .90    125000    25000
Merlot               Q4    28865    36550    kdollar.      .60 .90    125000    25000
;
run;

data data9;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Sauvignon Blanc      Q1    17677    15000    kdollar.      .60 .90    125000    25000
Sauvignon Blanc      Q2    35763    16700    kdollar.      .60 .90    125000    25000
Sauvignon Blanc      Q3    13790    18400    kdollar.      .60 .90    125000    25000
Sauvignon Blanc      Q4    12398    21500    kdollar.      .60 .90    125000    25000
;
run;

data data10;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Zinfandel            Q1    13876    13500    kdollar.      .60 .90    125000    25000
Zinfandel            Q2    10164    15030    kdollar.      .60 .90    125000    25000
Zinfandel            Q3    17876    16560    kdollar.      .60 .90    125000    25000
Zinfandel            Q4    18644    19350    kdollar.      .60 .90    125000    25000
;
run;

data data11;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
North America        Q1    78963    79500    kdollar.      .60 .90    125000    25000
North America        Q2    78138    86840    kdollar.      .60 .90    125000    25000
North America        Q3    91176    93840    kdollar.      .60 .90    125000    25000
North America        Q4    91441   107500    kdollar.      .60 .90    125000    25000
;
run;

data data12;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Asia                 Q1    28877    25500    kdollar.      .60 .90    125000    25000
Asia                 Q2    37472    29225    kdollar.      .60 .90    125000    25000
Asia                 Q3    48641    33120    kdollar.      .60 .90    125000    25000
Asia                 Q4    52944    39775    kdollar.      .60 .90    125000    25000
;
run;

data data13;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Europe               Q1    30811    30000    kdollar.      .60 .90    125000    25000
Europe               Q2    33032    33400    kdollar.      .60 .90    125000    25000
Europe               Q3    39948    36800    kdollar.      .60 .90    125000    25000
Europe               Q4    41253    43000    kdollar.      .60 .90    125000    25000
;
run;

data data14;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Middle East          Q1    12365    13500    kdollar.      .60 .90    125000    25000
Middle East          Q2    13081    15030    kdollar.      .60 .90    125000    25000
Middle East          Q3    15767    16560    kdollar.      .60 .90    125000    25000
Middle East          Q4    15592    19350    kdollar.      .60 .90    125000    25000
;
run;

data data15;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
South America        Q1    3041    1500    kdollar.      .60 .90    125000    25000
South America        Q2    3435    2505    kdollar.      .60 .90    125000    25000
South America        Q3    4206    3680    kdollar.      .60 .90    125000    25000
South America        Q4    5035    5375    kdollar.      .60 .90    125000    25000
;
run;

data data16;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Revenue              Q1 154057  150000   kdollar.    .60 .90 300000 100000
Revenue              Q2 165158  167000   kdollar.    .60 .90 300000 100000
Revenue              Q3 199738  184000   kdollar.    .60 .90 300000 100000
Revenue              Q4 206264  215000   kdollar.    .60 .90 300000 100000
;
run;

data data17;
   length value_format $15;
   input title_text $ 1-20 quarter $ 22-23 actual target value_format poor_pct good_pct y_max y_by;
   datalines;
Profit               Q1 31999  37500   kdollar.   .60 .80  60000  20000
Profit               Q2 36749  41750   kdollar.   .60 .80  60000  20000
Profit               Q3 42431  46000   kdollar.   .60 .80  60000  20000
Profit               Q4 46685  53750   kdollar.   .60 .80  60000  20000
;
run;

/* Run the do_chart macro for each chart, passing in the name of
the data set and the name of the GRSEG to store the output in. */
goptions nodisplay;
%do_chart(data1,plot1);
%do_chart(data2,plot2);
%do_chart(data3,plot3);
%do_chart(data4,plot4);
%do_chart(data5,plot5);
%do_chart(data6,plot6);
%do_chart(data7,plot7);
%do_chart(data8,plot8);
%do_chart(data9,plot9);
%do_chart(data10,plot10);
%do_chart(data11,plot11);
%do_chart(data12,plot12);
%do_chart(data13,plot13);
%do_chart(data14,plot14);
%do_chart(data15,plot15);
%do_chart(data16,plot16);
%do_chart(data17,plot17);

/**************************************************************************/
/* Create an overall title for the entire dashboard and also an overall 
legend using the GSLIDE procedure.  This slide is stored in a GRSEG named
titles  that is replayed into a dashboard template area that overlaps the 
entire dashboard output area.  The text on the slide is placed in the top 
right corner, where no charts are located. */

data titlanno;
   length function color $ 8 style $ 20 position $ 1 text $ 50;
   retain xsys ysys '3' hsys '3' when 'a'; 
   function='label'; 
   position='5'; 
   color='black'; 
   
   /* Annotated Title Text */
   x=75; 
   size=5; 
   style="&ftitle";
   y=96; text="&title1";
   output;
   size=3.5; 
   style="&ftext";
   y=y-6; text="&title2";
   output;
   y=y-5; text="&title3";
   output;
   
   /* Custom annotated legend */
   style="marker"; text='U'; size=3;
   x=45; 
   y=82; color="&red";
   output;
   y=y+4; color="&pink";
   output;
   y=y+4; color="&green";
   output;
   y=y+4; color="&gray"; size=2.5; text='A';
   output;
   
   style="markere"; text='U'; size=3;
   x=45; 
   y=82; color="&gray";
   output;
   y=y+4; color="&gray";
   output;
   y=y+4; color="&gray";
   output;
   
   style="&ftext"; size=2.2; color="black"; position='6';
   x=46.5; 
   y=82.3; text="Poor";
   output;
   y=y+4; text="Satisfactory";
   output;
   y=y+4; text="Good";
   output;
   y=y+4; text="Target";
   output;   
run;

/* Draw the title and legend on a blank slide and save the output in a 
   GRSEG named titlanno. */
goptions xpixels=900 ypixels=640;
title;
footnote;
proc gslide des="" name="titles" anno=titlanno;
run;

/**************************************************************************/
/* Create the dashboard. */

goptions display;
goptions xpixels=900 ypixels=640;
goptions cback=&backcolor;
 
ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm"
   (title="Sales Dashboard (DM Review Contest - Scenario 3)")
   style=minimal;
goptions border;

%let greout=white;
proc greplay tc=tempcat nofs igout=work.gseg;

/* Define the areas of a custom dashboard template. */
   tdef dashbrd des='Dashboard'

/* Entire dashboard area (used for overall title/legend) */
   0/llx = 0   lly =  0
     ulx = 0   uly =100
     urx =100  ury =100
     lrx =100  lry =  0

/* First 5-chart row (various metrics) */
   1/llx = 0   lly = 50
     ulx = 0   uly = 73
     urx =20   ury = 73
     lrx =20   lry = 50
   2/llx =20   lly = 50
     ulx =20   uly = 73
     urx =40   ury = 73
     lrx =40   lry = 50
   3/llx =40   lly = 50
     ulx =40   uly = 73
     urx =60   ury = 73
     lrx =60   lry = 50
   4/llx =60   lly = 50
     ulx =60   uly = 73
     urx =80   ury = 73
     lrx =80   lry = 50
   5/llx =80   lly = 50
     ulx =80   uly = 73
     urx =100  ury = 73
     lrx =100  lry = 50

/* Second 5-chart row (types of wine) */
   6/llx = 0   lly = 25
     ulx = 0   uly = 48
     urx =20   ury = 48
     lrx =20   lry = 25
   7/llx =20   lly = 25
     ulx =20   uly = 48
     urx =40   ury = 48
     lrx =40   lry = 25
   8/llx =40   lly = 25
     ulx =40   uly = 48
     urx =60   ury = 48
     lrx =60   lry = 25
   9/llx =60   lly = 25
     ulx =60   uly = 48
     urx =80   ury = 48
     lrx =80   lry = 25
  10/llx =80   lly = 25
     ulx =80   uly = 48
     urx =100  ury = 48
     lrx =100  lry = 25

/* Third 5-chart row (geographic locations) */
  11/llx = 0   lly = 0
     ulx = 0   uly = 23
     urx =20   ury = 23
     lrx =20   lry = 0
  12/llx =20   lly = 0
     ulx =20   uly = 23
     urx =40   ury = 23
     lrx =40   lry = 0
  13/llx =40   lly = 0
     ulx =40   uly = 23
     urx =60   ury = 23
     lrx =60   lry = 0
  14/llx =60   lly = 0
     ulx =60   uly = 23
     urx =80   ury = 23
     lrx =80   lry = 0
  15/llx =80   lly = 0
     ulx =80   uly = 23
     urx =100  ury = 23
     lrx =100  lry = 0

  /* Two charts in top left (revenue and profit) */
  16/llx = 0   lly = 76
     ulx = 0   uly = 99
     urx =20   ury = 99
     lrx =20   lry = 76
  17/llx =20   lly = 76
     ulx =20   uly = 99
     urx =40   ury = 99
     lrx =40   lry = 76
;

   /* Replay the individual indicators into the appropriate areas in the custom 
      dashboard template. */
   template = dashbrd;
   treplay 
      16:plot16 17:plot17  0:titles
       1:plot1   2:plot2   3:plot3   4:plot4   5:plot5 
       6:plot6   7:plot7   8:plot8   9:plot9  10:plot10
      11:plot11 12:plot12 13:plot13 14:plot14 15:plot15
      des=""
      name="&name";
run;
quit;

ODS HTML CLOSE;
ODS LISTING;
