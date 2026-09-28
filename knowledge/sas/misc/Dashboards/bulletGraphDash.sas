/* This example uses SAS/GRAPH software to generate a bullet graph 
dashboard, as described by in "Information Dashboard Design" 
(Stephen Few. 2006. Sebastopol, CA. O'Reilly Media, Inc.).  */

/* Specify the name for the output file. */
%let name=bulletGraphDash;

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

/* If you need more space for the labels on the left side of bullets,
   add more B's to this string. */
%let blank=BBBBBBBBBBBBBBBBBBB;

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

goptions xpixels=500 ypixels=125 noborder;

data temp_data; set &data_name;
run;

/* Read values from the indicator data set into macro variables. */
proc sql noprint;
   select range3 into :range3 from temp_data;
   select by_value into :by_value from temp_data;
   select unique value_format into :value_format from temp_data;
quit;     

%let range3=%trim(&range3);
%let by_value=%trim(&by_value);
%let value_format=%trim(&value_format);


/* Set the 'tool tip' for the chart to provide a link to an 
   HTML page with drill-down details. */
data temp_data; set temp_data;
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
   x=target; y=85; function='draw'; line=1; size=1.7; color="&barcolor";
   output;
   
   /* Annotate the midpoint value label to provide have the flexibility to 
      easily place multiple lines of text. */
   xsys='1'; ysys='1';
   x=-2; y=85; function='label'; when='a'; position='4'; style="&ftitle"; size=14; text=trim(left(mylabel));
   output;
   x=-2; y=30; function='label'; when='a'; position='4'; style="&ftext"; size=11; text=trim(left(mylabel2));
   output;
   
run;

/* Draw the custom bullet graph (consisting of a bar chart with 
   annotated color ranges behind it and an annotated target marker
   across the bar). */
goptions gunit=pct htitle=10 htext=9.5 ftitle=&ftitle ftext=&ftext;
goptions cback=&backcolor;


/* The offset to the right is important to guarantee that the bars will line up.
   Style=0 makes the axis lines invisible. */
axis1 order=(0 to &range3 by &by_value) major=(height=3) minor=none label=none offset=(0,9) style=0;

/* The offset here makes more room for the shaded area to be visible above 
   and below the bar. */
axis2 label=none value=(font=&ftext height=9 color=&backcolor) offset=(7,7) style=0;

/* Set the bar color. */
pattern1 v=s color=&barcolor;

title;
footnote;

proc gchart data=temp_data anno=myanno;
   format actual &value_format;
   hbar blank / discrete
      type=sum sumvar=actual
      raxis=axis1 maxis=axis2
      width=2.4  /* width of bar */
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

ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm"
   (title="Stephen Few's Bullet Graph Dashboard")
   gtitle gfootnote
   style=minimal;
goptions border;

goptions nodisplay;
goptions xpixels=600 ypixels=600;  

/* Title Slide */
goptions gunit=pct htitle=4 ftitle=&ftitle htext=3 ftext=&ftitle;
title ls=2.5 "Bullet Graph Dashboard";
title2 ls=2 "2005  YTD";
proc gslide des="" name="titles" /* anno=titlanno */;
run;


/* The indicator data set must have the folllowing variables
   because the macro is hard-coded to use them:
blank      blank space to annotate bar labels
mylabel    label beside bar
mylabel2   secondary label beside bar
target     target is annotated as thick mark
actual     value is length of black bar
by_value   by-value for axis tickmarks
range1     max value of dark gray area
range2     max value of middle gray area
range3     max value of light gray area (also end of raxis)
*/

/* Call the do_bullet macro five times using five different data sets.
   The resulting graphs will be saved into individual GRSEGs that can
   later be replayed them into a custom template to get all five on 
   the same page. */

options mprint;

data mydata;
   blank="&blank";
   mylabel='Revenue';
   mylabel2='U.S. $(1,000s)';
   target=250;
   actual=270;
   by_value=50;
   range1=150;
   range2=225;
   range3=300;
   value_format='comma7.0';
run;
%do_bullet(mydata,plot1);

data mydata;
   blank="&blank";
   mylabel='Profit';
   mylabel2='%';
   target=.27;
   actual=.225;
   by_value=.05;
   range1=.20;
   range2=.25;
   range3=.30;
   value_format='percent5.0';
run;
%do_bullet(mydata,plot2);

data mydata;
   blank="&blank";
   mylabel='Avg Order Size';
   mylabel2='U.S. $';
   target=550;
   actual=330;
   by_value=100;
   range1=350;
   range2=500;
   range3=600;
   value_format='comma7.0';
run;
%do_bullet(mydata,plot3);

data mydata;
   blank="&blank";
   mylabel='New Customers';
   mylabel2='Count';
   target=2050;
   actual=1750;
   by_value=500;
   range1=1400;
   range2=2000;
   range3=2500;
   value_format='comma7.0';
run;
%do_bullet(mydata,plot4);

data mydata;
   blank="&blank";
   mylabel='Cust Satisfaction';
   mylabel2='Top Rating of 5';
   target=4.5;
   actual=4.6;
   by_value=1;
   range1=3.5;
   range2=4.3;
   range3=5;
   value_format='comma7.0';
run;
%do_bullet(mydata,plot5);

goptions display;
goptions xpixels=600 ypixels=600;  

/* Create a custom greplay template.
   0 = whole screen (for the title slide)
   1-5 = spaces for the 5 bullet graphs) */
proc greplay tc=tempcat nofs igout=work.gseg;
   tdef bullets des='Bullet Dashboard'
   0/llx = 0   lly =  0
     ulx = 0   uly =100
     urx =100  ury =100
     lrx =100  lry =  0

   1/llx = 0   lly = 68
     ulx = 0   uly = 85
     urx =100  ury = 85
     lrx =100  lry = 68

   2/llx = 0   lly = 51
     ulx = 0   uly = 68
     urx =100  ury = 68
     lrx =100  lry = 51

   3/llx = 0   lly = 34
     ulx = 0   uly = 51
     urx =100  ury = 51
     lrx =100  lry = 34

   4/llx = 0   lly = 17
     ulx = 0   uly = 34
     urx =100  ury = 34
     lrx =100  lry = 17

   5/llx = 0   lly =  0
     ulx = 0   uly = 17
     urx =100  ury = 17
     lrx =100  lry =  0
   ;
run;

   /* Replay the title slide and the individual bullet graphs into the
      custom dashboard template. */
   template = bullets;
   treplay
      0:titles
      1:plot1         
      2:plot2         
      3:plot3         
      4:plot4         
      5:plot5         
      des=""
      name="&name";
run;
quit;

ODS HTML CLOSE;
ODS LISTING;
