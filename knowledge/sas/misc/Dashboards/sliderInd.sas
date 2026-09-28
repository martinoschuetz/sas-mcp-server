/* Specify the name for the output file. */
%let name=sliderInd;

/* Set output options. */
filename odsout '.';
goptions reset=all;
goptions device=gif;

/* Define range colors for the indicator bar. */
%let light_red=cxFFC1C1;
%let light_yellow=cxFFFFAA;
%let light_green=cxB4EEB4;

/* Define the color to use when the marker is in the alert area.  */
%let alert_color=cxff0000;

/* Define background and foreground colors for the indicator. */
%let backcolor=white;
%let darkcolor=black;

/* Define fonts for indicator title and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/*************************************************************************/
/* The following "do_range" macro creates a slider chart indicator showing 
a three-segment bar with a pointer to indicate your current value.  

This example assumes that the color specified in the light_red variable 
indicates an undesireable range of values.  If the pointer falls in a 
range represented in the light_red color, it is set to the color specified 
in the alert_color parameter to indicate that it needs attention.

Note that the range for undesireable values does not have to appear at 
the top of the scale. It could be at the bottom, both bottom and top, 
or in the middle, depending on the color parameters that you specify in 
the macro call.

The do_range macro accepts the following list of parameters:

pltname = name of GRSEG to store the chart
val1 = lowest value of lowest range in scale
val2 = highest value of lowest range in scale
val3 = lowest value of highest range in scale
val4 = highest value of highest range in scale
actual = actual value for indicator (value for pointer)
color1 = color for lowest range in scale
color2 = color for middle range in scale
color3 = color for highest range in scale
alert_color = bright attention-grabbing color if value is in "alert" range
valfmt = format to apply to the values
titletext = title to print above individual chart
*/

%macro do_range( pltname, val1, val2, val3, val4, actual, color1, color2, color3, alert_color, valfmt, titletext);

%local pltname val1 val2 val3 val4 actual color1 color2 color3 alert_color valfmt titletext;

goptions cback=&backcolor;

/* Add the parameter values to a SAS data set so that they can be 
   processed with the GCHART procedure.  Also specify the HTML file 
   to provide drill-down details. */
data tempdata;

length html $ 200;
html='title='||quote(
 'Actual Value: '|| trim(left(put(&actual,&valfmt)))
) ||' '||'href="'||"&hardcoded_drilldown"||'"';
barname='foo';
segnum=1; value=&val2-&val1;
output;
segnum=2; value=&val3-&val2;
output;
segnum=3; value=&val4-&val3;
output;
run;

/* Create Annotate data for the labels and pointer on the bar chart. */
data tempanno;
length style $20 color $ 12 function $ 8 text $ 30;
when="A";

/* Set the 'tool tip' for the chart to provide a link to an 
   HTML page with drill-down details. */
length html $ 200;
html='title='||quote(
 'Actual Value: '|| trim(left(put(&actual,&valfmt)))
) ||' '||'href="'||"&hardcoded_drilldown"||'"';

/* Draw a line across the bar at the point where the triangle marker goes. */
xsys='2'; ysys='2'; midpoint='foo'; y=&actual-&val1; function='move';
output;
size=1; color="&darkcolor";
function='draw'; xsys='B'; x=-7;
output;
function='draw'; xsys='B'; x=14;
output;

/* Position the cursor to draw the triangle marker pointer. */
xsys='2'; ysys='2'; midpoint='foo'; y=&actual-&val1; function='move';
output;
function='cntl2txt';
output;

/* Set the color of the triangular pointer.  If the triangular pointer 
   is in an area that uses the color specified in the light_red variable, 
   then set the area and the pointer to the color specified in the 
   alert_color parameter. */
alert_color=symget('alert_color');
if &actual lt &val1 then do;
 color="&backcolor";
 end;
else if &actual lt &val2 then do;
 color="&color1";
 if "&color1" eq "&light_red" then do;
   call symput('color1',alert_color);
   color="&alert_color";
   end;
 end;
else if &actual lt &val3 then do;
 color="&color2";
 if "&color2" eq "&light_red" then do;
   call symput('color2',alert_color);
   color="&alert_color";
   end;
 end;
else if &actual le &val4 then do;
 color="&color3";
 if "&color3" eq "&light_red" then do;
   call symput('color3',alert_color);
   color="&alert_color";
   end;
 end;
else do;
 color="&backcolor";
 end;

/* Draw the triangular pointer (using character 'A' of the 'marker' 
   software font provided with SAS/GRAPH software. */
function='label'; hsys='3'; ysys='2'; y=&actual-&val1; xsys='9'; x=5.00;
position='6'; size=5; style="marker"; text="A";
output;

/* Draw an outline around the triangle using the 'markere' font
   (empty/outline of the triangle marker). */
xsys='2'; ysys='2'; midpoint='foo'; y=&actual-&val1; function='move';
output;
function='cntl2txt';
output;
function='label'; hsys='3'; ysys='2'; y=&actual-&val1; xsys='9'; x=5.00;
position='6'; size=5; style="markere"; color="&darkcolor"; text="A";
output;

/* Annotate the actual value as text beside the triangle marker */
xsys='2'; ysys='2'; midpoint='foo'; y=&actual-&val1; function='move';
output;
function='cntl2txt';
output;
function='label'; hsys='3'; ysys='2'; y=&actual-&val1; xsys='9'; x=14;
position='C'; size=5; style="&ftitle"; color="&darkcolor";
text=trim(left(put(&actual,&valfmt)));
output;

/* Annotate the text for the beginning and end of each range along the
   left side of the bar. */
xsys='2'; ysys='2'; midpoint='foo'; y=&val1-&val1; function='move';
output;
function='cntl2txt';
output;
function='label'; hsys='3'; ysys='2'; xsys='9'; x=-9;
position='A'; size=5; style="&ftext"; color="&darkcolor"; 
y=&val1-&val1; text=trim(left(put(&val1,&valfmt)));
output;
x=0;
y=&val2-&val1; text=trim(left(put(&val2,&valfmt)));
output;
y=&val3-&val1; text=trim(left(put(&val3,&valfmt)));
output;
y=&val4-&val1; text=trim(left(put(&val4,&valfmt)));
output;

run;

/* Set the size for an individual slider chart indicator. */
goptions xpixels=400 ypixels=300;

title1 ls=1.5 color=&darkcolor &titletext;
pattern1 v=s c=&color1;
pattern2 v=s c=&color2;
pattern3 v=s c=&color3;

/* Draw the individual chart using the GCHART procedure and the custom 
   annotation.  Save the output in the GRSEG name identified by the 
   NAME= option so that it can later be be replayed it into a template 
   using the GREPLAY procedure. */
proc gchart data=tempdata anno=tempanno;
vbar barname /
   sumvar=value
   subgroup=segnum
   width=10
   coutline=gray
   noframe
   noaxis
   nolegend
   html=html
   des=""
   name="&pltname";  
run;
quit;

%mend do_range;

/*****************************************************************************************/

ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm" (title="IT Dashboard (individual chart)") style=minimal;
goptions border;

goptions gunit=pct htitle=7 ftitle=&ftitle htext=5 ftext=&ftext;

/* Run the macro with specified data values to create a dashboard indicator. */
%do_range(itcost,10000,30000,40000,50000,40458,&light_green,&light_yellow,&light_red,&alert_color,comma8.0,'IT Cost');

ODS HTML CLOSE;
ODS LISTING;
