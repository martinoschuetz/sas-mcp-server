/* Specify the name for the output file. */
%let name=dialMeterIndSTP;

/* Set output options. */
goptions reset=all;
goptions device=gif;

/* Define fonts for indicator title and text. */
%let ftitle='swissb';
%let ftext='swissl';

/* Define colors for dial meter features. */
%let label_color=black;
%let outer_ring_color=cx33A1C9;
%let inner_border_color=cx36648B;
%let outer_border_color=cx36648B;
%let gray_color=cxdddddd;
%let hub_color=white;
%let hub_border=black;
%let minor_tick_color=gray66;
%let major_tick_color=black;

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/**************************************************************************/
/* The do_gauge macro creates an individual dial meter indicator. The dial 
meter is created by specifying the values for the start-angle, end-angle, 
and color for each segment, along with a value to specify the position of 
the pointer for the gauge.

The do_gauge macro accepts the following list of parameters:

mydata = name of the data set that contains indicator values
major_tick_by = increment for major tick marks
minor_tick_by = increment for minor tick marks
titletext = title to print above individual chart
foottext = title to print below individual chart
pltname = name of GRSEG to store the chart
*/

%macro do_gauge(mydata, major_tick_by, minor_tick_by, titletext, foottext, pltname);

%local mydata major_tick_by minor_tick_by titletext foottext pltname;

proc sql noprint;
   select min(start) into :min_start from &mydata where (lowcase(grtype) eq 'segment');
   select max(end)   into :max_end from   &mydata where (lowcase(grtype) eq 'segment');
   select min(start) into :arrow_val from &mydata where (lowcase(grtype) eq 'arrow');
quit;     

data ranges arrow text; 
   length html $500;
   length text $100;
   length function color $ 8; 
   length style $ 20;
   set &mydata;
   xsys='3'; ysys='3'; hsys='3'; when='A';  

   /* Draw color range segments */
   if grtype eq 'segment' then do;
      x=50; y=50; size=32;
      function='PIE';
      style='PSOLID'; 
      min_start=&min_start;
      max_end=&max_end;
      percent_start=((start-&min_start)/(&max_end-&min_start));
      percent_end=((end-&min_start)/(&max_end-&min_start));
      angle_start=240-((start-&min_start)/(&max_end-&min_start))*300;
      angle_end=240-((end-&min_start)/(&max_end-&min_start))*300;
      angle=angle_end;
      rotate= 
      (240-((start-&min_start)/(&max_end-&min_start))*300) 
      - 
      (240-((end-&min_start)/(&max_end-&min_start))*300)
      ;
      output ranges;
   end;

   /* Draw an arrow pointer by first drawing a fake pie slice, then 
      positioning the cursor at 100% to the edge of this invisible slice, 
      then drawing a line back to the center of the chart (coordinate 50,50). */
   else if grtype eq 'arrow' then do;
      x=50; y=50; size=32;
      function='PIE'; when='b'; style='PSOLID';  /* real pie slice is invisible/behind */
      angle=240-((start-&min_start)/(&max_end-&min_start))*300;
      rotate=.1;
      output arrow;
      function='piexy'; size=1; /* With piexy size is the 'multiplier' for the previous pie's size */  
      output arrow;
      x=50; y=50; when='a'; function='draw'; size=.5;  /* size is width of line now */
      output arrow;

      /* Add text labels at the bottom and top of the pie (in conjunction with
         drawing the arrow, so it is done only once. */
      function='label'; color="&label_color";
      style="&ftitle";
      angle=0; rotate=0;
      position='5'; size=6;
      y=98; text="&titletext";
      output text;
      y=5;  text="&foottext";
      output text;
   end;
run;


/* The dial meter has several different color bands and borders.
   This is done by overlapping several pies. */
data behind middle front hub; 
   length function color $ 8; 
   length style $ 20;
   xsys='3'; ysys='3'; hsys='3'; when='A';  
   
   /* Position the center of the gauge in the center of the page. */
   x=50; y=50; 
   
   /* Set the 'tool tip' for the chart to provide a link to an 
      HTML page with drill-down details. */
   length html $ 200;
   html='title='||quote( trim(left("&arrow_val"))) ||' '|| 
   'href="'||"&hardcoded_drilldown"||'"';
      
   function='PIE'; style='PSOLID'; 
   angle=0;
   rotate=360;
   color="&outer_border_color"; size=42; output behind;  /* outer border */
   
   /* Ensure that the tool tip appears only for the outer/biggest pie slice. */
   html='';
   
   color="&outer_ring_color"; size=41; output behind;    /* outer color swatch/ring */
   color="&inner_border_color"; size=36; output behind;  /* inner color border */
   color="&gray_color"; size=35; output behind;          /* gray area */
   color="&gray_color"; size=29; output middle;          /* gray area, inside colored ranges */
   color="&gray_color"; size=27.5; output front;         /* innermost gray area (chops the major tickmarks) */
   color="&hub_color";  size=2; output hub;              /* white center */
   color="&hub_border"; size=2; style="pempty"; output hub; /* black ring around white center */
run;

/* Draw the minor tick marks.  The process is similar to drawing the 
   arrow/pointer line, except that ticks overlap a smaller gray pie on 
   top of them so you don't see the whole line, but only the piece of the 
   line in the "tick" area. */
data minorticks;
   length text $100;
   length function color $ 8;
   length style $ 20;
   xsys='3'; ysys='3'; hsys='3';
   do tick = &min_start to &max_end by &minor_tick_by;
      x=50; y=50; size=32;
      function='PIE'; when='b'; style='pempty';  /* real pie slice is invisible/behind */
      angle=240-((tick-&min_start)/(&max_end-&min_start))*300;
      rotate=.1;
      output;
      function='piexy'; size=1;
      output;
      x=50; y=50; color="&minor_tick_color"; when='a'; function='draw'; size=.1;
      output;
   end;
run;

/* Major ticks marks are done in the same way as the minor ticks. */
data majorticks;
   length text $100;
   length function color $ 8;
   length style $ 20;
   xsys='3'; ysys='3'; hsys='3';
   do tick = &min_start to &max_end by &major_tick_by;
      x=50; y=50; size=32;
      function='PIE'; when='b'; style='pempty';  /* real pie slice is invisible/behind */
      angle=240-((tick-&min_start)/(&max_end-&min_start))*300;
      rotate=.1;
      output;
      function='piexy'; size=1;
      output;
      x=50; y=50; color="&major_tick_color"; when='a'; function='draw'; size=.1;  output;
   end;
run;

data majornums;
   length text $100;
   length function color $ 8;
   length style $ 20;
   xsys='3'; ysys='3'; hsys='3';
   do tick = &min_start to &max_end by &major_tick_by;
      x=50; y=50; size=32;
      function='PIE'; when='b'; style='pempty';  /* real pie slice is invisible/behind */
      angle=240-((tick-&min_start)/(&max_end-&min_start))*300;
      rotate=.1;
      output;
      function='piexy'; size=.75;
      output;
      function='cntl2txt';
      output;
      function='label'; when='a'; text=trim(left(tick)); angle=0; rotate=0; 
      position='5'; style="&ftext"; size=4.25; x=.; y=.;
      output;
   end;
run;

data gaugeanno; 
   set behind ranges minorticks middle majorticks front majornums arrow hub text;
run;

proc ganno annotate=gaugeanno des="" name="&pltname";                                               
run;                                                                            
quit;

%mend do_gauge;

/**************************************************************************/

/* Create an example data set with the variables required by the 
   do_gauge macro. */
data my_data2;
   length grtype color $ 8;    
   input  grtype color start end;
   datalines;
segment cxff0000  0  50
segment cx00cd00 50 100 
arrow   black     11 .  
;
run;

goptions border;

%let _GOPT_DEVICE=gif;
%let _ODSOPTIONS=gtitle gfootnote style=minimal;
%stpbegin;

goptions device=gif;
goptions xpixels=400 ypixels=300;
options mprint;

/* Call the macro  with specified data values to draw a dial meter indicator. */
%do_gauge(my_data2,10,5,Scheduling,Percent Bid When Scheduled,sched1);

%stpend;
