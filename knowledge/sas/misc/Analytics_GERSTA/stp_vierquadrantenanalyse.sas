%global erster;
%global zweiter;

%let _ODSSTYLE=test;
/*
%let erster=Anbieter A;
%let zweiter=Anbieter C;
*/
%stpbegin;




/* Vier-Quadranten-Analyse */
libname aaa "D:\DATEN\Quellen";


data aaa.grafikdaten;
  set aaa.stp_vqa;
  where anbieter in ("&erster","&zweiter");
run;

goptions device=activex xpixels=600	ypixels=600;
ods html;
Data aaa.annotiert;
   Set aaa.grafikdaten;
   XSYS = '2'; YSYS = '2';
   X = satisfaction; Y = importance;
   FUNCTION='LABEL';
   TEXT=_LABEL_;
   POSITION='3';
   SIZE=6;
run;



proc means data=aaa.stp_vqa noprint;
  var satisfaction importance;
  output out=aaa.sumstats mean(satisfaction)=avg_satisfaction
                       mean(importance)=avg_importance
                       min(satisfaction)=min_satisfaction
					   min(importance)=min_importance
					   max(satisfaction)=max_satisfaction
					   max(importance)=max_importance
;
run;


data _NULL_;
  set aaa.sumstats;
  if _N_=1 then call symput("avg_satisfaction",avg_satisfaction);
  if _N_=1 then call symput("avg_importance",avg_importance);
  if _N_=1 then call symput("min_importance",min_importance);
  if _N_=1 then call symput("min_satisfaction",min_satisfaction);
  if _N_=1 then call symput("max_importance",max_importance);
  if _N_=1 then call symput("max_satisfaction",max_satisfaction);
run;

%put &avg_satisfaction;
%put &avg_importance;
%put &min_importance;
%put &max_importance;
%put &min_satisfaction;
%put &max_satisfaction;

axis1 order=(0.5 to 4.5 by 1) label=('Satisfaction Rating');
axis2 order=(0.5 to 4.5 by 1) label=('Importance Rating');

title;
title j=center height=16pt "Vier-Quadranten-Analyse: " &erster " vs. " &zweiter;
/*title3 j=center "<img src='D:\DATEN\aaa\logo.png' height=40 border=5>";*/

PROC GPLOT data=aaa.grafikdaten;
     PLOT importance*satisfaction=anbieter / anno=aaa.annotiert
     HAXIS=axis1 VAXIS=axis2
     LHREF=1 CHREF=BLACK HREF=&avg_satisfaction
	 LVREF=1 CVREF=BLACK VREF=&avg_importance;
run;
quit;

ODS html close;

%stpend;
