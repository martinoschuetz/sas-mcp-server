/* This example uses SAS/GRAPH software to generate a bullet graph 
indicator, as described by in "Information Dashboard Design" 
(Stephen Few. 2006. Sebastopol, CA. O'Reilly Media, Inc.).  */

/* Specify the name for the output file. */
%let name=bulletGraphInd;

/* Set output options. */
filename odsout '.';
goptions reset=all;
goptions device=gif;

/* Define range colors for the bullet graphs. */
%let color1=gray88;
%let color2=graybb;
%let color3=graydd;

/* Define bar and background colors for the indicator. */
%let barcolor=black;
%let backcolor=white;

/* Define fonts for indicator title and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/**************************************************************************/
/* The do_bullet macro creates an individual bullet graph indicator.

The do_bullet macro accepts the following list of parameters:

data_name = name of the data set that contains indicator values
pltname = name of GRSEG to store the graph
*/

%macro do_bullet(data_name,pltname);

%local data_name pltname;

data temp_data; 
   set &data_name;
run;

/* Read values from the indicator data set into macro variables. */
proc sql noprint;
   select titletext into :titletext from temp_data;
   select range3    into :range3    from temp_data;
   select by_value  into :by_value  from temp_data;
   select unique value_format into :value_format from &data_name;
quit;     

%let value_format=%trim(&value_format);
%let titletext=%trim(&titletext);

/* Set the 'tool tip' for the chart to provide a link to an 
   HTML page with drill-down details. */
data temp_data;
   set temp_data;
   length myhtml $200;
   myhtml='title='||quote( 
   'Value: '||trim(left(put(actual,&value_format)))||'0d'x||
   'Target: '||trim(left(put(target,&value_format)))||
   ' ')||' '||
   'href="'||"&hardcoded_drilldown"||'"';
run;

data myanno;
   set temp_data; 
   length function $8 color $12 style $20 text $20;
   hsys='3';
   
   /* Annotate three colored areas (bars), representing the three ranges of values.
      Use when='b' so these will show up behind the real bar chart bar. */
   xsys='2'; ysys='1'; style='solid'; when='b'; 
   
   x=0; y=0; function='move';
   output;
   x=range1; y=100; function='bar'; color="&color1";
   output;
   
   x=range1; y=0; function='move';
   output;
   x=range2; y=100; function='bar'; color="&color2";
   output;
   
   x=range2; y=0; function='move';
   output;
   x=range3; y=100; function='bar'; color="&color3";
   output;
   
   /* Annotate a thick line representing the target value. */
   x=target; y=15; function='move';
   output;
   x=target; y=85; function='draw'; line=1; size=1.5; color='black';
   output;
   
   /* Annotate the midpoint value label to provide the flexibility to 
      easily place multiple lines of text. */
   xsys='1'; ysys='1';
   x=-2; y=70; function='label'; when='a'; position='4'; style="&ftitle"; size=9; 
   text=trim(left(mylabel));
   output;
run;

/* Draw the custom bullet graph (consisting of a bar chart with 
   annotated color ranges behind it and an annotated target marker
   across the bar). */
goptions gunit=pct htitle=10 htext=7.5 ftitle=&ftitle ftext=&ftext;
goptions xpixels=600 ypixels=200;
goptions cback=&backcolor;

axis1 order=(0 to &range3 by &by_value) minor=none label=none offset=(0,0) style=0;

axis2 label=none value=(font=&ftitle height=9 color=&backcolor) offset=(3,3);

pattern1 v=s color=&barcolor;

title "&titletext";

proc gchart data=temp_data anno=myanno;
   format actual &value_format;
   hbar mylabel / discrete
      type=sum
      sumvar=actual
      raxis=axis1
      maxis=axis2
      width=1.8
      coutline=same
      nolegend
      nostats
      noframe
      html=myhtml
      des=""
      name="&pltname";
run;
quit;

%mend do_bullet;

/**************************************************************************/

/* Create an example data set with the variables required by the 
   do_bullet macro. */
data data1;
   titletext='Bullet Graph';
   mylabel='YTD Units';
   actual=4773;
   target=6250;
   value_format='comma7.0';
   range1=3500;
   range2=5500;
   range3=8000;
   by_value=1000;
run;
 
ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm" (title="Stephen Few's Bullet Graph") 
   gtitle gfootnote style=minimal;
goptions border;

/* Call the macro  with specified data values to draw a bullet graph indicator. */
%do_bullet(data1,bull1);

ODS HTML CLOSE;
ODS LISTING;
