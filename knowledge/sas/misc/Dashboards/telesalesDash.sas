/* This example uses SAS/GRAPH software to generate a version of the telesales
performance dashboard described on p. 199 of  "Information Dashboard Design"
(Few, Stephen. 2006. Sebastopol, CA. O'Reilly Media, Inc.).  */

/* Specify the name for the output file. */
%let name=telesalesDash;
filename odsout '.';

%let backcolor=cxFFFFEb;
%let textcolor=cxAEBB51; 

%let good=graybb;
%let excessive=graydb;
%let critical=grayef;

%let red_dot=red;
%let orange_dot=orange;

/* Define fonts for indicator and dashboard titles and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/***************************************************************************/
/* Create sample data sources for the dashboard indicators. */

/* Data for plot1 (Overall Rep Performance) */
data data1;
   format percent_of_target percentn7.0;
   input category $ 1-15 percent_of_target actual_value;
   datalines;
Hold Time             .95 63
Call Duration        1.80 4756
Abandonments          .80 27
run;

/* Data for plot2 (Today (compared to target) sparklines) */
data data2;
   input category timestamp percent_of_target;
   length category_name $20;
   if (category eq 1) then category_name='Abandonments';
   else if (category eq 2) then category_name='Call Duration';
   else if (category eq 3) then category_name='Hold Time';
   datalines;
1 1 .50
1 2 .75
1 3 .50
1 4 .60
1 5 1.25
1 6 .70
1 7 .66
1 8 .60
2 1 .80
2 2 .75
2 3 .70
2 4 1.00
2 5 1.20
2 6 .90
2 7 1.25
2 8 1.30
3 1 .75
3 2 .70
3 3 .65
3 4 .75 
3 5 1.10
3 6 .90
3 7 .85
3 8 .80 
;
run;

/* Data for plot3 (Rep Utilization) */
data data3; 
   format value percentn7.0;
   input barnum segment value;
   datalines;
1 1 .85
1 2 .05
1 3 .10
;
run;

/* data for plot4 sparklines (Volume) */
data data4;
   input category timestamp percent_of_target;
   length category_name $20;
   if (category eq 1) then category_name='Order Count';
   else if (category eq 2) then category_name='Call Count';
   datalines;
2 1 .50
2 2 .95
2 3 .60
2 4 .60
2 5 1.15
2 6 1.10
2 7 1.0
2 8 1.0
1 1 .70
1 2 .75
1 3 .70
1 4 1.00
1 5 1.20
1 6 1.10
1 7 1.20
1 8 1.20
;
run;

/* Data for the table to the left of plot4 (Volume) */
data data4_table;
   input cat_name $ 1-20 category this_hour today this_month;
   datalines;
Call Count           2 373 1322 25934
Order Count          1 234 925 17834
;
run;

/* Data for plot5 (Mean Hourly Calls per Rep Today)*/
data data5;
   input calls_per_rep $ 1-5 reps;
   calls_per_rep=trim(left(calls_per_rep));
   datalines;
 0-4   0
 5-9   0
10-14  5
15-19 10
20-24  8
25-29  1
30-34  0
;
run;

/* Data for plot6 (Mean Hourly Orders per Rep Today) */
data data6;
   input orders_per_rep $ 1-5 reps;
   orders_per_rep=trim(left(orders_per_rep));
   datalines;
 0-3   0
 4-7   3
 8-11  6
12-15 11
16-19  4
20-23  1
24-27  0
;
run;

/* Data for plot7 (Individual Rep Performance) */
/* Since SAS/GRAPH does not have a procedure to create horizontal boxplots, 
   this plot uses the Annotate facility to draw them. If real data points
   were available, the numbers for the boxplots could be calculated as 
   follows: 

 proc boxplot data=data7;
    plot Call_Duration*Name /
       outhistory=data7_anno;
 run;

 Because actual data points are not available in this sample, estimated 
 values are used. */
data data7;
   input Text $ 1-20 Orders_Per_Hour Calls_Per_Hour Call_DurationL Call_Duration1 Call_DurationM Call_Duration3 Call_DurationH;
   Offline=substr(Text,1,1);
   if Offline eq '.' then Offline=' ';
   Name=trim(left(substr(Text,3,18)));
   sort_order=Orders_Per_Hour+(Calls_Per_Hour/100);
   datalines;
. Jacobs, S           5 10  0.5 6.1  8.2 11.0 17.5 
. McKinsey, J         5 13  1.0 5.8  9.5 13.0 20.2
. Smith, V            6 12  3.0 8.8 11.0 13.1 17.2
. Wilcox, R           9 14  2.0 6.1  9.0 11.5 16.0
. Clark, P           10 14  1.5 5.5  9.0 12.6 18.7
. Simons, B          10 16  2.5 6.0  9.3 11.8 14.8
. Newman, A          11 15  3.0 6.0 8.5 10.5 14.0
. Bailey, S          11 16  2.9 6.8 9.0 11.0 18.1
. Barclay, T         11 17  0.8 4.5 7.0 12.0 17.0
. Jimenez, J         12 16  0.9 6.3 8.4 10.6 16.5
X Chou, A            12 17  2.0 4.5 5.9 9.0 19.0
. Kata, H            12 17  2.9 5.0 7.5 8.8 16.5
. Silverman, C       13 18  3.0 7.0 8.0 10.0 15.0
. Schuster, P        13 18  3.0 6.5 8.0 11.0 17.0
. Truman, M          13 19  2.3 6.1 7.8 10.5 16.3
X Pierce, B          14 19  0.4 5.0 7.0 10.0 15.0
. Fisher, J          14 20  2.7 4.5 6.3 9.0 14.3
. Jung, T            14 20  2.1 5.0 6.5 10.0 18.0
. English, S         15 21  2.2 6.8 7.5 10.0 14.0
. Wiley, P           15 21  2.0 5.7 8.5 12.0 17.0
. Johnson, N         16 21  3.0 5.0 8.7 13.0 15.0
X Lucas, J           16 22  3.0 5.5 8.3 13.0 17.0
. Forester, R        17 23  3.0 7.0 8.5 11.0 16.5
;
run;

/* The following macro variables are used by multiple plots. */
proc sql noprint;
select unique count(*) into :repcount from data7;
select unique count(*) into :reponline from data7 where offline^="X";
select unique &reponline/&repcount into :reppercent from data7;
quit;     

/**************************************************************************/

goptions device=gif;
goptions cback=&backcolor;
goptions noborder;

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

/**************************************************************************/
/* Create the individual dashboard indicators. */

/* Set the NODISPLAY option to save the plots as GRSEGS 
   without writing them to the output. */
goptions nodisplay;

/*  plot1 - Overall Rep Performance (bar chart) */

/* Create chart tip and drill-down for the bars in plot1 */
data data1;
   set data1;
   length myhtml $ 250;
   myhtml='title='||quote(
      trim(left(category)) ||'0D'x||
      trim(left(put(percent_of_target,percentn7.0)))||' = Percent of Target '||'0D'x||
      trim(left(put(actual_value,comma12.0)))||' = Actual Value'
      ) ||' '|| 'href="'||"&hardcoded_drilldown"||'"';
run;

/* Create annotation that is specific to each individual bar. */
data data1_anno;
   set data1;
   length function $8 color style $20 text $40;
   xsys='2'; ysys='2'; hsys='3'; 
   
   ysys='2'; midpoint=category;
   xsys='3'; x=0; position='6';
   
   /*  Annotate the bar values to the right of the plot.
   Horizontal bar charts have some built-in capability to do this, 
   but this sample attempts to replicate Few's, so annotating the 
   values to gives more precise control. */
   function='label'; style="&ftext"; size=5; color="black";
   xsys='3'; x=93; position='4';
   text=trim(left(put(actual_value,comma8.0)));
   output;
   
   /* Annotate colored dots beside bars that need attention.
   The 'dot' is the 'W' character of the MARKER font supplied
   with SAS/GRAPH software.  (If this bar needs no attention, 
   then the dot is the same color as the background, which 
   makes it invisible.) */
   xsys='3'; x=6; function='move';
   output;
   ysys='7'; y=8.0;
   output; 
   function='label'; style='marker'; text='W'; size=7;
   if percent_of_target > 1.75 then color="&red_dot";
   else if percent_of_target > .90 then color="&orange_dot";
   else color="&backcolor";
   output;
run;

/* Create annotation that is not specific to the individual
   bars, but more general to the whole graph. */
data data1_anno2;
   length function $8 color style $20 text $40;
   hsys='3'; when='a';
   
   /* Annotate the main title and a few items of text over plot1. */
   function='label'; 
   color="&textcolor"; style="&ftext";
   size=10;
   xsys='3'; x=1;
   ysys='3'; y=96;
   position='6';
   text='Overall Rep Performance';
   output;
   color="black"; style="&ftext";
   size=6;
   ysys='1'; y=100;
   xsys='1'; x=0;
   position='3';
   text='% of Target';
   output;
   xsys='1'; x=100;
   position='3';
   text='  Actual';
   output;
   
   /* Annotate the three color-range areas behind the bar chart. */
   xsys='2'; ysys='1';  when='b'; style='solid'; 
   function='move'; x=0; y=0;
   output;
   function='bar'; color="&good"; line=1; size=.1; x=.9; y=100;
   output;
   function='move'; x=.9; y=0;
   output;
   function='bar'; color="&excessive"; line=1; size=.1; x=1.75; y=100;
   output;
   function='move'; x=1.75; y=0;
   output;
   function='bar'; color="&critical"; line=1; size=.1; x=2.50; y=100;
   output;
run;

goptions xpixels=300 ypixels=175; 
goptions gunit=pct ftitle=&ftitle ftext=&ftext htitle=4 htext=5.5;
title1 h=18 " ";
title2 a=90 h=11 " ";
title3 a=-90 h=18 " ";
footnote1 h=5 " ";
axis1 label=none order=('Hold Time' 'Call Duration' 'Abandonments') offset=(8,8);
axis2 label=none order=(0 to 2.5 by .5) value=(h=5) minor=none offset=(0,0);
pattern1 v=s c=gray55;
proc gchart data=data1 anno=data1_anno;
   hbar category / nostats
      maxis=axis1
      raxis=axis2
      caxis=gray99
      ref=1 cref=black
      width=3
      space=3
      type=sum sumvar=percent_of_target
      anno=data1_anno2
      html=myhtml
      des=""
      name="plot1";
run;

/* plot2 */
/* "Sparkline" graphs are challenging to create with SAS/GRAPH software.
   This example uses the GPLOT procedure, and for each line an offset is
   added so that the lines are plotted aboveor below each other, rather 
   than on top of each other.  Also note that each line is plotted as a 
   percentage of the target, rather than as raw seconds. (If you plot as 
   raw seconds, it is impossible to scale the lines so they can be compared.) */
data data2; set data2;
   y=(2*category)-1+percent_of_target;
run;

/* Annotate the title, to get it in the exact desired location,
   to line up with some text in graph to the left */
data data2_anno;
   length function $8 color style $20 text $40;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   function='label'; position='5'; style="&ftext"; 
   size=5.75; color="black";
   x=50; y=82; text='Today (compared to target)';
   output;
   size=5.5; color="gray77";
   x=50; y=16; text='(Sparklines scaled as % of target)';
   output;

   /* Annotate an invisible drill-down covering entire graph area (because
   you can't do drill-downs on plot lines without markers. */
   xsys='1'; ysys='1'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
       'href="'||"&hardcoded_drilldown"||'"';
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

goptions xpixels=200 ypixels=200; 
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=8 htext=6.5;
axis1 label=none order=(0 to 8 by 2) value=none major=none minor=none style=0;
axis2 label=(' ') order=(1 to 12 by 2) value=none major=none minor=none style=0;
symbol v=none i=join width=.1 c=black repeat=100;
title1 h=8 " ";
title2 " ";
title3 a=90 h=5 " ";
title4 a=-90 h=5 " ";
footnote h=.5 " ";
proc gplot data=data2 anno=data2_anno;
   plot y*timestamp=category / 
      noframe
      vaxis=axis1
      haxis=axis2
      vref= 2 4 6
      cvref=graycc
      nolegend
      des=""
      name="plot2";
run;

/* plot3 */
data data3;
   set data3;
   length myhtml $ 250;
   myhtml='title="drilldown"' ||' '|| 
      'href="'||"&hardcoded_drilldown"||'"';
run;

data data3_anno;
   length function $8 color style $20 text $40;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   
   function='label';
   xsys='3'; ysys='3'; 
   x=1; y=84; position='6'; size=20; style="&ftext"; color="&textcolor";
   text="Rep Utilization";
   output;
   
   xsys='3'; ysys='3'; 
   color="black";
   function='label'; size=12;
   x=85; 
   y=70; 
   style="&ftext"; 
   text="Reps Online: "; position='4';
   output;
   x=x+1;
   style="&ftitle"; 
   text=trim(left("&reponline")); position='6';
   output;
   x=85; 
   y=50; 
   style="&ftext"; 
   text="Reps Today: "; position='4';
   output;
   x=x+1;
   style="&ftitle"; 
   text=trim(left("&repcount")); position='6';
   output;
   x=92.5;
   y=60; 
   text="="; position='4';
   output;
   text=trim(left(put(&reppercent,percent7.0))); position='6';
   output;
   function='move'; x=86; y=58;
   output;
   function='draw'; x=x+2.5; color="black"; line=1; size=.1;
   output;
   
   /* Colored dot at left side of chart */
   ysys='2'; midpoint=1; 
   xsys='3'; x=2; 
   function='move';
   output;
   function='label'; style='marker'; text='W'; size=14 ;
   if &reppercent < .85 then color="&red_dot";
   else if &reppercent < .90 then color="&orange_dot";
   else color="&backcolor";
   output;
   
   position='5'; text=''; color="black"; 
   function='move'; xsys='2'; x=&reppercent; ysys='1'; y=0;
   output;
   function='draw'; size=2.5; line=1; y=100;
   output;
run;

goptions xpixels=600 ypixels=125;  
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=15 htext=10;
axis1 label=none value=none offset=(8,8);
axis2 label=none order=(.75 to 1.00 by .05) minor=none offset=(0,0);
pattern1 v=s c=&critical;
pattern2 v=s c=&excessive;
pattern3 v=s c=&good;
title h=20 " ";
title2 a=-90 h=99 " ";
title3 a=-90 h=30 " ";
title4 a=90 h=13 " ";
footnote;
proc gchart data=data3 anno=data3_anno;
   hbar barnum / discrete
      type=sum
      sumvar=value
      subgroup=segment
      width=8
      space=0
      coutline=gray55
      maxis=axis1
      raxis=axis2
      caxis=gray99
      nolegend
      nostats
      noframe
      html=myhtml
      des=""
      name="plot3";
run;

/* plot4 */
/* Annotate the title to get it in the exact desired location,
   so that it lines up with text in graph to the left. */
data data4_table; set data4_table; 
 y_position=(2*category)-1;
run;

data data4_anno; set data4_table;
   length function $8 color style $20 text $40;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   function='label'; style="&ftext";
   
   if _n_ eq 1 then do;
      x=1; y=90; position='6'; size=20; style="&ftext"; color="&textcolor";
      text="Volume";
      output;
      
      position='5'; style="&ftext"; 
      size=11; color="black";
      xsys='1'; x=50; y=85; text='Per Hour Today';
      output;
      
      function='label'; 
      size=11; color="black";
      style="&ftitle"; 
      xsys='3'; 
      
      position='4'; 
      ysys='3'; 
      y=85;
      x=35; text='This Hour';
      output;
      x=48; text='Today';
      output;
      x=62; text='This Month';
      output;
   end;
   
   ysys='2'; y=y_position;
   
   size=11;
   style="&ftitle"; position='3';
   x=12; text=trim(left(cat_name));
   output;
   
   size=12;
   style="&ftext"; position='1'; 
   x=35; text=trim(left(put(this_hour,comma12.0)));
   output;
   x=48; text=trim(left(put(today,comma12.0)));
   output;
   x=62; text=trim(left(put(this_month,comma12.0)));
   output;
run;

data data4; set data4;
   y_position=(2*category)-1+percent_of_target;
run;

/* Annotate an invisible drill-down covering the entire graph area (because
you can't do drill-downs on plot lines without markers. */
data data4_anno2;
   xsys='3'; ysys='3'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
    'href="'||"&hardcoded_drilldown"||'"';
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

goptions xpixels=600 ypixels=125;
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=5 htext=4;

axis1 label=(h=10 '                                ') 
   order=(0 to 6 by 2) value=none 
   major=none minor=none style=0;
axis2 label=none order=(1 to 12 by 2) value=none major=none minor=none style=0;
symbol v=none i=join width=.1 c=black repeat=100;

/* This controls the white-space around the sparkline plot.
In particular, the title2 statement adds a lot of space to the left. */
title1 h=1 " ";
title2 a=90 h=100 " ";
title3 a=-90 h=2 " ";
footnote h=.1 " ";

proc gplot data=data4 anno=data4_anno;
   plot y_position*timestamp=category / 
      noframe
      vaxis=axis1
      haxis=axis2
      vref= 2 4 
      cvref=graycc
      nolegend
      anno=data4_anno2
      des=""
      name="plot4";
run;

/* plot5 */
data data5; set data5;
   length myhtml $ 250;
   myhtml='title='||quote(
      trim(left(reps)) ||' reps made '|| trim(left(calls_per_rep))||' mean hourly calls today.'
      ) ||' '|| 'href="'||"&hardcoded_drilldown"||'"';
run;

goptions xpixels=275 ypixels=200; 
goptions gunit=pct ftitle=&ftitle ftext=&ftext htitle=6 htext=3.75;
title1 h=1 " ";
title2 h=3 a=-90 " ";
footnote;
axis1 label=(h=4 'Reps') order=(0 to 12 by 2) minor=none;
axis2 label=(h=4 'Mean Hourly Calls per Rep Today') 
   value=(h=3.2) order=('0-4' '5-9' '10-14' '15-19' '20-24' '25-29' '30-34');
pattern1 v=s c=graybb;
proc gchart data=data5;
   vbar calls_per_rep /
      type=sum
      sumvar=reps
      raxis=axis1
      maxis=axis2
      coutline=gray55
      width=12
      space=0
      noframe
      html=myhtml
      des=""
      name="plot5";
run;

/* plot6 */
data data6; set data6;
   length myhtml $ 250;
   myhtml='title='||quote(
      trim(left(reps)) ||' reps had '|| trim(left(orders_per_rep))||' mean hourly orders today.'
      ) ||' '|| 'href="'||"&hardcoded_drilldown"||'"';
run;

goptions xpixels=275 ypixels=200; 
goptions gunit=pct ftitle=&ftitle ftext=&ftext htitle=6 htext=3.75;
title1 h=1 " ";
title2 h=3 a=-90 " ";
footnote;
axis1 label=(h=4 'Reps') order=(0 to 12 by 2) minor=none;
axis2 label=(h=4 'Mean Hourly Orders per Rep Today') 
   value=(h=3.2) order=('0-3' '4-7' '8-11' '12-15' '16-19' '20-23' '24-27');
pattern1 v=s c=graybb;
proc gchart data=data6;
   vbar orders_per_rep /
      type=sum
      sumvar=reps
      raxis=axis1
      maxis=axis2
      coutline=gray55
      width=12
      space=0
      noframe
      html=myhtml
      des=""
      name="plot6";
run;

/* plot7 */
proc sort data=data7 out=data7;
   by sort_order;
run;

data data7_anno;
   set data7;
   badrank=_n_;
run;

data data7_anno; set data7_anno;
   xsys='2'; ysys='2'; hsys='3'; when='a';
   length function color $8 style $20;
   
   length html $ 250;
   html='title='||quote(
    trim(left(Name)) ||'0D'x||
    trim(left(Orders_Per_Hour))||' Orders Per Hour '||'0D'x||
    trim(left(Calls_Per_Hour))||' Calls Per Hour'||'0D'x||
    'Median Call Duration: '|| trim(left(Call_DurationM))||' minutes'
     ) ||' '|| 'href="'||"&hardcoded_drilldown"||'"';
   
   color="gray";
   size=.1;
   /* draw the outer box */
   ysys='2';
   midpoint=Name;
   function='move'; x=Call_DurationL;
   output;
   function='move'; ysys='7'; y=-.3;
   output;
   function='bar'; line=0; style='solid'; x=Call_DurationH; y=+.6;
   output;
   /* draw the inner box */
   ysys='2';
   midpoint=Name;
   function='move'; x=Call_Duration1;
   output;
   function='move'; ysys='7'; y=-.7;
   output;
   function='bar'; line=0; style='solid'; x=Call_Duration3; y=+1.4;
   output;
   /* Median Line (median is Call_DurationM, mean is Call_DurationX) */
   color="white";
   ysys='2';
   midpoint=Name;
   function='move'; x=Call_DurationM;
   output;
   function='move'; ysys='7'; y=-.7;
   output;
   function='bar'; line=0; style='solid'; x=Call_DurationM; y=+1.4;
   output;
   
   /* This sample sends email rather than an instant message.  Notice that a 
      dummy email address is supplied.In a production dashboard, you would 
      want to have a field in your data with a real email address rather than 
      a static address in the code. */
   length html $ 250;
   html='title='||quote(
    trim(left(Name)) ||'0D'x||
    'Median Call Duration: '|| trim(left(Call_DurationM))||' minutes'
    ) ||' '|| 'href="mailto:'||trim(left(scan(Name,1,',')))||
    '@some_telesales_company.com?subject=Mail from Telesales Dashboard"';
   
   /* Labels along the left */
   function='label'; size=2.1; color="black"; style="&ftext";
   if badrank <= 4 then do;
      color='red';
      style="&ftext";
   end;
   ysys='2'; midpoint=Name;
   xsys='3'; 
   position='6';
   x=2; text=trim(left(Offline));
   output;
   x=6; text=trim(left(Name));
   output;
   
   /* Annotate text labels */
   html='';
   position='4';
   x=35; text=trim(left(Orders_Per_Hour));
   output;
   x=45; text=trim(left(Calls_Per_Hour));
   output;
run;

data data7_anno2;
   length function $8 color style $20 text $40;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   function='label'; position='6';
   y=99; x=2;
   style="&ftext"; size=3.5; color="&textcolor"; text='Individual Rep Performance';
   output;
   style="&ftext"; size=2.0; color="black";
   y=93;
   x=25.5; text='Orders';
   output;
   x=40; text='Calls';
   output;
   y=91;
   x=6;  text='Name';
   output;
   x=26; text='Per Hr';
   output;
   x=40; text='Per Hr';
   output;
   x=58; text='Call Duration (minutes)';
   output;
   y=3; x=2; text='(X = Currently offline)';
   output;
run;

goptions gunit=pct ftitle=&ftitle ftext=&ftext htitle=4 htext=2;
goptions xpixels=400 ypixels=685; 
title1 ls=4.5 " ";
title2 a=90 h=20pct " ";
footnote;
axis1 offset=(2,2) label=none value=none;
axis2 order=(0 to 21 by 3) major=(height=.5) minor=none label=('Call Duration (minutes)') offset=(0,0);

pattern1 v=e c=white;
proc gchart data=data7 anno=data7_anno;
   hbar Name / 
      type=sum sumvar=sort_order ascending nostats
      maxis=axis1
      raxis=axis2
      caxis=gray99
      anno=data7_anno2
      des=""
      name="plot7";
run;

/***************************************************************************/

data titlanno;
   length function $8 color style $20 text $100;
   length html $ 250;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   
   /* Annotate the main title at the bottom/left of the dashboard. */
   function='label'; position='6';
   x=0; y=2.5; size=4.3; style="&ftext"; color="&textcolor"; text='Telesales Dashboard';
   output;
   
   /* Annotate the light green lines that group and separate the various parts
   of the dashboard. */
   line=1; size=.2; color="&textcolor";
   function='move'; x=0; y=4.5;
   output;
   function='draw'; x=100;
   output;
   function='move'; x=0; y=55;
   output;
   function='draw'; x=60;
   output;
   function='move'; x=0; y=70;
   output;
   function='draw'; x=60;
   output;
   function='move'; x=60; y=4.5;
   output;
   function='draw'; y=100;
   output;
   
   /* Annotate a Help button in the bottom right of the dashboard. 
   Assign the HTML drill-down so that when the user clicks
   the Help button, they will see information about the dashboard. */
   html='title='||quote('Help')||' '||'href="'||"&hardcoded_drilldown"||'"';
   function='move'; x=90; y=0;
   output;
   function='bar'; line=0; size=.1; style='solid'; color="&backcolor"; x=x+6; y=y+3;
   output;
   html='';
   function='move'; x=90; y=0;
   output;
   function='bar'; line=0; size=.1; style='empty'; color="gray77"; x=x+6; y=y+3;
   output;
   function='label'; style="&ftext"; size=2.0; x=90+3; y=2; position='5'; text='Help';
   output;
   
   /* Annotate a helpful message below the list of rep names, to let the user know
   they can click the rep name to send them a message. */
   function='label'; style="&ftext"; size=2.0; x=62; y=1.5; position='6'; 
   text='Click rep to send instant message';
   output;
   
   /* Annotate a custom color legend at the bottom middle of the dashboard.
      This color legend is shared by the left top and left middle charts. */
   function='label'; style="&ftext"; size=2.0; 
   x=35; y=1.5; position='6'; 
   text='(   Good;   Excessive;   Critical )';
   output;
   function='label'; size=1.1; positon='5'; y=1.1;
    style='marker'; text='U';
    x=36.3; color="&good";
   output;
    x=42.6; color="&excessive";
   output;
    x=51.8; color="&critical";
   output;
    style='markere'; color="gray77"; text='U';
    x=36.3;
   output;
    x=42.6;
   output;
    x=51.8;
   output;
run;

/* Use the GSLIDE procedure to display the custom text and graphics. */
title; 
footnote;
goptions xpixels=925 ypixels=685; 
proc gslide des="" name="titles" anno=titlanno;
run;

/**************************************************************************/

goptions device=gif;
goptions xpixels=925 ypixels=685; 
goptions display;
goptions border;

ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm" (title="Telesales Dashboard") 
    style=minimal gtitle gfootnote;

/* Create a custom template, with seven areas for the plots
   and one area for the title slide. */
proc greplay tc=tempcat nofs igout=work.gseg;
   tdef murder des='Murder'

   0/llx = 0   lly =  0
     ulx = 0   uly =100
     urx =100  ury =100
     lrx =100  lry =  0

   1/llx = 0   lly =70 
     ulx = 0   uly =100
     urx = 40  ury =100
     lrx = 40  lry =70 

   2/llx = 40  lly =70 
     ulx = 40  uly =100
     urx = 60  ury =100
     lrx = 60  lry =70 

   3/llx =  0  lly =55 
     ulx =  0  uly =70 
     urx = 60  ury =70 
     lrx = 60  lry =55 

   4/llx =  0  lly =38 
     ulx =  0  uly =53 
     urx = 60  ury =53 
     lrx = 60  lry =38 

   5/llx =  0  lly =5  
     ulx =  0  uly =40 
     urx = 30  ury =40 
     lrx = 30  lry =5  

   6/llx = 30  lly =5  
     ulx = 30  uly =40 
     urx = 60  ury =40 
     lrx = 60  lry =5  

   7/llx = 60  lly =  5
     ulx = 60  uly =100
     urx = 100 ury =100
     lrx = 100 lry =  5
;

   /* Replay the individual indicators and the title slide into the custom template. */
   template = murder;
   treplay
      1:plot1 2:plot2     
      3:plot3 7:plot7
      4:plot4
      5:plot5 6:plot6
      0:titles
      des=""
      name="&name";
run;
quit;

ODS HTML CLOSE;
ODS LISTING;
