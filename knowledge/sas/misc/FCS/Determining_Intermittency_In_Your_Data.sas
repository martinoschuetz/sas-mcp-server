/*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$*/
/*         INTERMITTENCY FREQUENCY CALCULATION PROGRAM                     */
/* This program is designed to help you quantify the effect of             */
/* intermittency in your data.  It seeks to answer the question "Is my     */ 
/* data intermittent?" and can be used for guidance in selecting           */
/* the correct value for the intermittency test specified in HPF software. */
/* Note1:  This program uses the median of the intervals to replicate      */
/*         the intermittency test produced in HPF                          */
/* Note2:  A 1-0-1-0-1-0 pattern will produce an intermttency of 2.0,      */
/*         whereas a 1-0-0-1-0-0-1-0-0-1 gives an intermittency of 3.0     */
/* Note3:  This program expects the data coming in to be sorted by product */ 
/*         id (part, SKU, etc.) and date (a required format for most SAS   */ 
/*         forecasting processes to run correctly). The array processing   */ 
/*         is used to transpose the data so that each part id has monthly  */
/*         buckets which can be used to count intervals for intermittency. */
/* Note4:  Only actuals (forecast fit region) are included in testing      */
/* Note5:  The idea is to count interval width through the array and to    */
/*         keep appending new values to a macro variable (&varmed) that is */
/*         used as input for the median function                           */
/* Note6:  The %sysfunc execution of the median function has to run in the */
/*         macro region (versus the data step region), hence the call      */
/*         execute at the bottom (and not a resolve function or alternate) */
/* Note7:  The default value in HPF to determine intermittency is 1.25     */ 
/* Program written June 13-14, 2005                                        */
/* Written by: Phil Weiss, SAS CSA Forecasting Analytics                   */
/*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$*/
data input1; /* The following data set is provided for testing/illustrative purposes only. */
             /* Intermittency values will be 3.5 (part 37) and 1 (part 42) respectively.  */
   format date monyy7.; 
   infile cards;
   input @5  part_id 
         @8  date    monyy7. 
         @20 demand    8.;
   cards;
    37 JAN2000     0
	37 FEB2000     0
	37 MAR2000     0
	37 APR2000     1
	37 MAY2000     0
	37 JUN2000     2
	37 JUL2000     0
	37 AUG2000     0
	37 SEP2000     1
	37 OCT2000     0
	37 NOV2000     0
	37 DEC2000     1
    37 JAN2001     0
	37 FEB2001     3
	37 MAR2001     0
	37 APR2001     0
	37 MAY2001     0
	37 JUN2001     3
	37 JUL2001     0
	37 AUG2001     0
	37 SEP2001     0
	37 OCT2001     0
	37 NOV2001     0
	37 DEC2001     2
    37 JAN2002     0
	37 FEB2002     0
	37 MAR2002     0
	37 APR2002     0
	37 MAY2002     1
	37 JUN2002     0
	37 JUL2002     0
	37 AUG2002     0
	37 SEP2002     1
	37 OCT2002     0
	37 NOV2002     0
	37 DEC2002     0
    42 JAN2000     0
	42 FEB2000     0
	42 MAR2000     3
	42 APR2000     3
	42 MAY2000     1
	42 JUN2000     1
	42 JUL2000     0
	42 AUG2000     0
	42 SEP2000     0
	42 OCT2000     0
	42 NOV2000     3
	42 DEC2000     0
    42 JAN2001     2
	42 FEB2001     3
	42 MAR2001     0
	42 APR2001     1
	42 MAY2001     2
	42 JUN2001     0
	42 JUL2001     0
	42 AUG2001     3
	42 SEP2001     0
	42 OCT2001     0
	42 NOV2001     0
	42 DEC2001     0
    42 JAN2002     0
	42 FEB2002     0
	42 MAR2002     0
	42 APR2002     1
	42 MAY2002     0
	42 JUN2002     0
	42 JUL2002     0
	42 AUG2002     0
	42 SEP2002     6
	42 OCT2002     3
	42 NOV2002     4
	42 DEC2002     1
   ;
run;
data calc1;
   set input1;
   retain d1-d36 i j;
   keep part_id d1-d36 inttot intcnt fintcnt intermittency flag cnt temp;
   array dem {36} d1-d36;
   by part_id;
   cnt=1; /* this is for printing later on */
   if first.part_id
      then i=1;
      else i=i+1;
   dem{i}=demand;
   if last.part_id
      then do;
	     /* Note: This routine does not start counting interval width until  */
         /* positive values at the beginning of a series are reached.        */
         do j=1 to 36; 
	        if j=1
               then do;
			      call execute('%let valmed= ;'); /* this zeros out the macro var for repeated use */
                  inttot=0;
                  intcnt=0;
				  fintcnt=0;
				  flag=0;
                  j+1; 
               end;
            if dem{j}=0
			   then intcnt=intcnt+1;
            if dem{j}>=1
			   then do;
			      intcnt=intcnt+1;
			      if flag=1
                     then do;
					    fintcnt=fintcnt+1;
						if fintcnt=1
						   then do;
						      /* Begin constructing a string for the median function to use */
                              call symput('intmed',left(intcnt)); 
							  call execute('%let valmed=&intmed;');
						   end;
                           else do;
						      /* Add a comma and the new interval count to a macro var and       */
						      /* append the new interval onto the existing input string (valmed) */
                              call symput('intmed',","||left(intcnt));
							  call execute('%let valmed=&valmed.&intmed;'); 
						   end;
					 end;
			      intcnt=0;
				  flag=1;  /* set flag to start counting past first non-zero bucket */
			   end;
		 end;
		 if fintcnt>0
		    then do;
			    /* Now perform the median function in the macro region using the input string */
			    temp=resolve('&valmed');  /* used just for quality control purposes */
			    call execute ('%let intermit=%sysfunc(median(&valmed.));');
				intermittency=input(symget('intermit'),8.);
			end;
			else intermittency=0;
         output;
	  end;
run;
ods graphics on;
ods html body     = "sample_b.html"
         frame    = "sample_f.html"
         contents = "sample_c.html";
ods listing close;
goptions xpixels=0 ypixels=0 device=activex;
pattern1 color=CX008080;
pattern2 color=CXFABC46;
pattern3 color=CXCD0367;
pattern4 color=CX3F769A;
pattern5 color=CXFF8600;
pattern6 color=CX45AB90;
pattern7 color=CXCA4DB0;
pattern8 color=CXF6D3A5;
pattern9 color=CX274776;
pattern10 color=CXFF72B0;
pattern11 color=CXB0C1F4;
pattern12 color=CX7DFF88;
axis1
	style=1
	width=1
	minor=none
	label=(font='Microsoft Sans Serif' height=12pt justify=right);
axis2
	style=1
	width=1
	label=(font='Microsoft Sans Serif' height=12pt justify=center);
title;
title1 "Bar Chart";
footnote;
footnote1 "Generated by the SAS System (Running on &sysscpl) on %sysfunc(date(), eurdfde9.) at %sysfunc(time(), timeampm8.)";
proc gchart data=calc1;
	vbar3d	 intermittency / sumvar=cnt midpoints=.5 .75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 4.0 4.5 5.0 10.0 20.0
	shape=block
	frame
	type=sum
	sum
	nolegend
	coutline=black
	raxis=axis1
	maxis=axis2
    patternid=midpoint
	lref=1
	cref=black
	autoref
;
run;
quit;
ods graphics off;
ods html close;
ods listing;


