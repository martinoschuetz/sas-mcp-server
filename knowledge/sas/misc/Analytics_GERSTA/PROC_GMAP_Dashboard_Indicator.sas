%global _ODSSTYLE _GOPT_DEVICE _GOPTIONS _ODSOPTIONS;
%let _ODSSTYLE=sasweb;
%let _GOPT_DEVICE=activex;
%let _GOPTIONS=%str(ftext=swissl transparency noninterlaced htitle=1.5);

/* ---------------------------------------------------------------------------------------------------------------- */
%global thevalue thename thetitle thefootnote;

%stpbegin;

/* ---------------------------------------------------------------------------------------------------------------- */
%macro csfASmap(colors=red yellow green,ranges=,csfvalue=,csfname=,csfformat=,csftitle=,footnote=,height=,width=);
%let valname=Wertebereich;
%let typname=Typ;
%let typmember=Bereich;
%let segname=Segment;


data _null_;
  i=1;
	call symput('hbseg0',scan("&ranges",1,' '));
  do while (scan("&colors",i,' ') ne '');
    call symput('colseg'||trim(left(put(i,2.))),scan("&colors",i,' '));
		call symput('hbseg'||trim(left(put(i,2.))),scan("&ranges",i+1,' '));
	  i=i+1;
	end;
	call symput('seg_num',trim(left(put(i-1,2.))));
run;
%put _user_;

%let deg2rad=0.017453;
%let range=%eval(&&&hbseg&seg_num-&hbseg0);
%let dvalue=%sysevalf(180-((&csfvalue-&hbseg0)/&range)*180);

data tmp;
  fmtname='tmp'; type='n';
	%do i=1 %to &seg_num;
	  %let im1=%eval(&i-1);
    start=&i;
    label=trim(left(put(&&&hbseg&im1,&csfformat)))||" - "||trim(left(put(&&&hbseg&i,&csfformat)));
    output;
  %end;
  start=&seg_num+1;
	label="&csfname"||"= "||left(put(&csfvalue,&csfformat));
	output;
run;
proc format cntlin=tmp;
run;

data csf;
  format &valname tmp.;
  &typname="&typmember";
  %do i=1 %to &seg_num;
	  %let im1=%eval(&i-1);
	  &segname=&i;
		&valname=&i;
		output;
	%end;
	&typname="CSF";
	&segname=&seg_num+1;
	&valname=&seg_num+1;
  output;
run;

data csfmap;
%do i=1 %to &seg_num;
  %let im1=%eval(&i-1);
	&segname=&i;
  do i=(180-((&&&hbseg&im1-&hbseg0)/&range)*180) to (180-((&&&hbseg&i-&hbseg0)/&range)*180) by -1;
    x=cos(i*&deg2rad);
    y=sin(i*&deg2rad);
    output;
  end;
	x=cos((180-((&&&hbseg&i-&hbseg0)/&range)*180)*&deg2rad);
	y=sin((180-((&&&hbseg&i-&hbseg0)/&range)*180)*&deg2rad);
  output;

  x=0.1*cos((180-((&&&hbseg&i-&hbseg0)/&range)*180)*&deg2rad);
	y=0.1*sin((180-((&&&hbseg&i-&hbseg0)/&range)*180)*&deg2rad);
	output;
  do i=(180-((&&&hbseg&i-&hbseg0)/&range)*180) to (180-((&&&hbseg&im1-&hbseg0)/&range)*180) by 1;
    x=0.1*cos(i*&deg2rad);
    y=0.1*sin(i*&deg2rad);
    output;
  end;
	%if &i=1 %then %do;
  x=-0.1;y=0;output;
	%end;
%end;
  &segname=%eval(&seg_num+1);
  x=-0.1;y=0;output;
	do i=180 to (&dvalue+6) by -1;
	  x=0.1*cos(i*&deg2rad);y=0.1*sin(i*&deg2rad);output;
	end;
	x=0.1*cos((&dvalue+6)*&deg2rad);y=0.1*sin((&dvalue+6)*&deg2rad);output;
  x=0.95*cos((&dvalue+0.7)*&deg2rad);y=0.95*sin((&dvalue+0.7)*&deg2rad);output;
	x=0.95*cos((&dvalue+3)*&deg2rad);y=0.95*sin((&dvalue+3)*&deg2rad);output;
	x=cos(&dvalue*&deg2rad);y=sin(&dvalue*&deg2rad);output;
	x=0.95*cos((&dvalue-3)*&deg2rad);y=0.95*sin((&dvalue-3)*&deg2rad);output;
	x=0.95*cos((&dvalue-0.7)*&deg2rad);y=0.95*sin((&dvalue-0.7)*&deg2rad);output;
	x=0.1*cos((&dvalue-6)*&deg2rad);y=0.1*sin((&dvalue-6)*&deg2rad);output;
	do i=(&dvalue-6) to 0 by -1;
	  x=0.1*cos(i*&deg2rad);y=0.1*sin(i*&deg2rad);output;
	end;
	x=0.1;y=0;output;
run;

TITLE;
TITLE1 "&thetitle.";
FOOTNOTE;
*FOOTNOTE1 "&thefootnote.";

GOPTIONS xpixels=&width ypixels=&height
         CBACK=WHITE
				 Device=Activex
         colors=(
%do i=1 %to &seg_num;
  &&&colseg&i
%end;
         white);
/*
Legend1
	FRAME
	POSITION=(BOTTOM CENTER OUTSIDE)
	LABEL=(FONT='Microsoft Sans Serif' HEIGHT=8pt JUSTIFY=Left)
;
*/
PROC GMAP  DATA=WORK.csf MAP=csfmap;
	ID &segname;
  PRISM Wertebereich /
  AREA=&valname
  DISCRETE
/*  LEGEND=Legend1 */
  NOLEGEND
  COUTLINE=grey
  XVIEW=0.5
	YVIEW=-0.6
	ZVIEW=3;
RUN; QUIT;
%mend;

/* ---------------------------------------------------------------------------------------------------------------- */

%csfASmap(colors=red orange yellow green, ranges=0 25 50 75 100,
	csfvalue=&thevalue, csfname=&thename, csfformat=COMMAX17.2, csftitle=&thetitle,
	footnote=&thefootnote, height=117, width=250);

%stpend;
