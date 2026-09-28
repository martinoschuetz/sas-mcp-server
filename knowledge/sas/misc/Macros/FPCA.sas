/* Functional PCA macro documentation
Overview
Means to analyze and compare time series
Allows extraction of FPCs from a collection of time series that can be used to compare time series to each other
Takes the functional data as input and outputs the functional principal components for each time series and the eigenvectors and their respective eigenvalues
Input
•	Mandatory parameters:
a)	 input_data_set, the data set that contains all the variables described below
b)	analysis_variable, the variable whose functional principal components are to be analysed. It is measured on a regular basis and forms time series analogous to functional data
c)	time_variable, a time dimension (starting at t= 0 for each function),
d)	ID_variable, a variable in the input data set that identifies each function/TS that has to be compared with the others,
e)	output_data_set, the name of the data set that will contain the first principal components 
•	Optional parameters:
a)	max_knots (optional), the number of knots of a spline to fit to the data (default = 20)
b)	FPC_cutoff (optional), the minimum relative contribution of the FPCs to be retained for output (default .01 (equivalent to 1%));
Output
•	Output_data_set, containing the FPC scores of each ID
•	Eigenfunctions, a data set containing each retained eigenvector with its contribution (eigenvalue / sum of all eigenvalues) 
Details
The macro consists of 3 parts:
•	First, a spline is fitted to the time series data to smooth it (by default, the macro fits splines of degree 3 with 20 knots ; this behaviour can be overridden by using the maximum_knots optional parameter to specify another number of knots)
•	Second, the smoothed time series are transposed and regularized so that all time series have the same length and data is present as a max_duration x number_of_IDs matrix where rows are successive time stamps, columns are IDs and each cell contains the value of the &analysis_variable at time i for ID j
•	Third, a regular PCA is run on the smoothed and transposed data and the most important FPCs are kept (by default, all FPCs that contribute to at least 1% of the variance are kept. This can be overridden using the FPC_cutoff optional parameter to specify another cutoff value (0 < FPC_cutoff < 1). Kept FPC scores of each ID are output in the output_data_set and the eigenvectors and their respective eigenvalues (or contribution) are output in the &analysis_variable_eigenvectors data set
*/

/* ----------------------------------------
Code exported from SAS Enterprise Guide
DATE: vrijdag 13 september 2019     TIME: 14:18:39
PROJECT: Recticel data prep
PROJECT PATH: C:\Users\sbxyab\OneDrive - SAS\Documents\stagair\orop41\Chapter 2\Demos\Recticel data prep.egp
---------------------------------------- */

%macro _eg_hidenotesandsource;
	%global _egnotes;
	%global _egsource;
	
	%let _egnotes=%sysfunc(getoption(notes));
	options nonotes;
	%let _egsource=%sysfunc(getoption(source));
	options nosource;
%mend _eg_hidenotesandsource;


%macro _eg_restorenotesandsource;
	%global _egnotes;
	%global _egsource;
	
	options &_egnotes;
	options &_egsource;
%mend _eg_restorenotesandsource;


/* ---------------------------------- */
/* MACRO: enterpriseguide             */
/* PURPOSE: define a macro variable   */
/*   that contains the file system    */
/*   path of the WORK library on the  */
/*   server.  Note that different     */
/*   logic is needed depending on the */
/*   server type.                     */
/* ---------------------------------- */
%macro enterpriseguide;
%global sasworklocation;
%local tempdsn unique_dsn path;

%if &sysscp=OS %then %do; /* MVS Server */
	%if %sysfunc(getoption(filesystem))=MVS %then %do;
        /* By default, physical file name will be considered a classic MVS data set. */
	    /* Construct dsn that will be unique for each concurrent session under a particular account: */
		filename egtemp '&egtemp' disp=(new,delete); /* create a temporary data set */
 		%let tempdsn=%sysfunc(pathname(egtemp)); /* get dsn */
		filename egtemp clear; /* get rid of data set - we only wanted its name */
		%let unique_dsn=".EGTEMP.%substr(&tempdsn, 1, 16).PDSE"; 
		filename egtmpdir &unique_dsn
			disp=(new,delete,delete) space=(cyl,(5,5,50))
			dsorg=po dsntype=library recfm=vb
			lrecl=8000 blksize=8004 ;
		options fileext=ignore ;
	%end; 
 	%else %do; 
        /* 
		By default, physical file name will be considered an HFS 
		(hierarchical file system) file. 
		*/
		%if "%sysfunc(getoption(filetempdir))"="" %then %do;
			filename egtmpdir '/tmp';
		%end;
		%else %do;
			filename egtmpdir "%sysfunc(getoption(filetempdir))";
		%end;
	%end; 
	%let path=%sysfunc(pathname(egtmpdir));
    %let sasworklocation=%sysfunc(quote(&path));  
%end; /* MVS Server */
%else %do;
	%let sasworklocation = "%sysfunc(getoption(work))/";
%end;
%if &sysscp=VMS_AXP %then %do; /* Alpha VMS server */
	%let sasworklocation = "%sysfunc(getoption(work))";                         
%end;
%if &sysscp=CMS %then %do; 
	%let path = %sysfunc(getoption(work));                         
	%let sasworklocation = "%substr(&path, %index(&path,%str( )))";
%end;
%mend enterpriseguide;

%enterpriseguide


/* Conditionally delete set of tables or views, if they exists          */
/* If the member does not exist, then no action is performed   */
%macro _eg_conditional_dropds /parmbuff;
	
   	%local num;
   	%local stepneeded;
   	%local stepstarted;
   	%local dsname;
	%local name;

   	%let num=1;
	/* flags to determine whether a PROC SQL step is needed */
	/* or even started yet                                  */
	%let stepneeded=0;
	%let stepstarted=0;
   	%let dsname= %qscan(&syspbuff,&num,',()');
	%do %while(&dsname ne);	
		%let name = %sysfunc(left(&dsname));
		%if %qsysfunc(exist(&name)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;

			%end;
				drop table &name;
		%end;

		%if %sysfunc(exist(&name,view)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;
			%end;
				drop view &name;
		%end;
		%let num=%eval(&num+1);
      	%let dsname=%qscan(&syspbuff,&num,',()');
	%end;
	%if &stepstarted %then %do;
		quit;
	%end;
%mend _eg_conditional_dropds;


/* save the current settings of XPIXELS and YPIXELS */
/* so that they can be restored later               */
%macro _sas_pushchartsize(new_xsize, new_ysize);
	%global _savedxpixels _savedypixels;
	options nonotes;
	proc sql noprint;
	select setting into :_savedxpixels
	from sashelp.vgopt
	where optname eq "XPIXELS";
	select setting into :_savedypixels
	from sashelp.vgopt
	where optname eq "YPIXELS";
	quit;
	options notes;
	GOPTIONS XPIXELS=&new_xsize YPIXELS=&new_ysize;
%mend _sas_pushchartsize;

/* restore the previous values for XPIXELS and YPIXELS */
%macro _sas_popchartsize;
	%if %symexist(_savedxpixels) %then %do;
		GOPTIONS XPIXELS=&_savedxpixels YPIXELS=&_savedypixels;
		%symdel _savedxpixels / nowarn;
		%symdel _savedypixels / nowarn;
	%end;
%mend _sas_popchartsize;


ODS PROCTITLE;
OPTIONS DEV=PNG;
GOPTIONS XPIXELS=0 YPIXELS=0;
FILENAME EGHTMLX TEMP;
ODS HTML(ID=EGHTMLX) FILE=EGHTMLX
    ENCODING='utf-8'
    STYLE=HTMLBlue
    STYLESHEET=(URL="file:///C:/Program%20Files%20(x86)/SASHome/x86/SASEnterpriseGuide/7.1/Styles/HTMLBlue.css")
    NOGTITLE
    NOGFOOTNOTE
    GPATH=&sasworklocation
;

/*   START OF NODE: FPCA macro   */
%_eg_hidenotesandsource;

%LET _CLIENTTASKLABEL='FPCA macro';
%LET _CLIENTPROCESSFLOWNAME='Process Flow';
%LET _CLIENTPROJECTPATH='C:\Users\sbxyab\OneDrive - SAS\Documents\stagair\orop41\Chapter 2\Demos\Recticel data prep.egp';
%LET _CLIENTPROJECTPATHHOST='sbxyab19';
%LET _CLIENTPROJECTNAME='Recticel data prep.egp';
%LET _SASPROGRAMFILE='';
%LET _SASPROGRAMFILEHOST='';

GOPTIONS ACCESSIBLE;
%_eg_restorenotesandsource;

/* FPCA macros */

*sub-macros;

*this low-level macro fits a spline to a variable called analysis_variable with time_variable as the time dimension, 
both present in the input_data_set, and identifies each TS to which a spline has to be fitted with the ID_variable;

%macro spline_fit(input_data_set, analysis_variable, time_variable, ID_variable, max_knots);
	
	proc sort data= &input_data_set;
		by &ID_variable;
	run;

	proc transreg data= &input_data_set noprint;
		by &ID_variable;
		model identity(&analysis_variable)= spline(&time_variable / nknots= &max_knots degree= 3);
		output out= work.&analysis_variable._spline predicted pprefix= PRED;
	run;

%mend spline_fit;

* this low_level macro transposes and cleans the TS/functional data so that it is in the form required for a classical PCA
to produce the functional PCA results;
*hypothesizes that if all TS do not have same length, the shorter ones have analysis variable = 0;
%macro pca_data_prep(analysis_variable, time_variable, ID_variable);

	proc sort data= work.&analysis_variable._spline;
		by &ID_variable &time_variable;
	run;

	%global longuest_shot;

	proc sql noprint;
		select max(&time_variable)
		into :longuest_shot
		from work.&analysis_variable._spline;
	
	data work.regular_&analysis_variable._spline;
		set work.&analysis_variable._spline;
		keep &ID_variable PRED&analysis_variable &time_variable;
		by &ID_variable;
		if last.LotID then do;
			PRED&analysis_variable= 0;
			do i= &time_variable to &longuest_shot - 1;
				&time_variable+ 1;
				output;
			end;
		end;
	run;
	
	data work.regular_&analysis_variable._spline;
		merge work.&analysis_variable._spline work.regular_&analysis_variable._spline;
		by &ID_variable &time_variable;
	run;

	proc delete data= work.&analysis_variable._spline;
	run;

	proc sort data= work.regular_&analysis_variable._spline out= work.regular_&analysis_variable._spline;
		by &ID_variable &time_variable;
	run;

	proc transpose data= work.regular_&analysis_variable._spline out= work.regular_&analysis_variable._spline_trans;
		by &ID_variable;
		id &time_variable;
		var PRED&analysis_variable;
	run;

	proc delete data= work.regular_&analysis_variable._spline;
	run;

	/* /!\ replaces all missings with 0 */
	*this is more pre-processing, should be done prior to using macro so I put it in comments;

	/*
	proc stdize data= work.&analysis_variable._spline_trans reponly missing= 0
				out= work.&analysis_variable._spline_trans;
	run;
	*/

	data work.&analysis_variable._spline_trans;
		set work.regular_&analysis_variable._spline_trans;
		drop _name_ _label_ ;
	run;

	proc delete data= work.regular_&analysis_variable._spline_trans;
	run;

%mend pca_data_prep;

* PCA using the covariance matrix;

%macro pca(analysis_variable, ID_variable);

	proc princomp data= &analysis_variable._spline_trans
					out= work.&analysis_variable._pca 
					outstat= work.&analysis_variable._stats cov
					prefix= &analysis_variable._FPC
					noprint;
		id &ID_variable;
	run;

	proc delete data= work.&analysis_variable._spline_trans;
	run;

%mend pca;

*extraction of the most important FPCs (FPCs with contribution > 1% selected);
%macro fpcs_extraction(analysis_variable, ID_variable, output_data_set, FPC_cutoff);

	data work.&analysis_variable._eigenval;
		set work.&analysis_variable._stats;
		drop _name_;
		where _type_ = "EIGENVAL";
	run;

	proc transpose data= work.&analysis_variable._eigenval 
					out= work.&analysis_variable._eigenval_trans;
	run;	

	data work.&analysis_variable._eigenvec;
		set work.&analysis_variable._stats;
		rename _name_= FPC;
		drop _type_;
		where _type_ = 'SCORE';
	run;

	proc delete data= work.&analysis_variable._stats
						work.&analysis_variable._eigenval;
	run;

	proc sql noprint;

		select compress(cat("&analysis_variable._FPC", put(input(_name_, best.) + 1, char.)), ' ')
		into :PC_names separated by ' '
		from work.&analysis_variable._eigenval_trans
		having COL1/sum(COL1) > &FPC_cutoff;

		create table work.&analysis_variable._FPC_contrib as
			select compress(cat("&analysis_variable._FPC", put(input(_name_, best.) + 1, char.)), ' ') as FPC, 
					COL1/sum(COL1) as Contribution
			from work.&analysis_variable._eigenval_trans
			having COL1/sum(COL1) > &FPC_cutoff;

		create table work.&analysis_variable._eigen as
			select *
			from work.&analysis_variable._eigenvec as a,
				work.&analysis_variable._FPC_contrib as b
			where a.FPC = b.FPC;
	quit;
	%put &PC_names;

	proc delete data= work.&analysis_variable._eigenvec
						work.&analysis_variable._FPC_contrib
						work.&analysis_variable._eigenval_trans;
	run;
	
	data &output_data_set ;
		set work.&analysis_variable._pca;
		keep &ID_variable &PC_names;
	run;
	
	
	proc delete data= work.&analysis_variable._pca;
	run;

	proc transpose data= work.&analysis_variable._eigen
					out= work.&analysis_variable._eigen;
		ID FPC;
	run;

%mend fpcs_extraction;

/* macro */

*this macro produces the functional first principal components of a data set of functional (time series) data;
*its parameters : input_data_set, the data set that contains all the variables described below
				analysis_variable, the variable whose functional principal components are to be analysed. It is measured on a regular basis and forms time series analogous to functional data
				time_variable, a time dimension, STARTING AT t= 0 (otherwise some FPCs will be lost), 
				ID_variable, a variable in the input data set that identifies each function/TS that has to be compared with the others,
				output_data_set, the name of the data set that will contain the first principal components (can be an already existing data set to which the FPCs will be added using a right outer join);
%macro functional_pca(input_data_set, analysis_variable, time_variable, ID_variable, output_data_set= work.&analysis_variable._FPCs, max_knots= 20, FPC_cutoff= .01);

	%spline_fit(input_data_set= &input_data_set, analysis_variable= &analysis_variable, time_variable= &time_variable, ID_variable= &ID_variable, max_knots= &max_knots)
	%pca_data_prep(analysis_variable= &analysis_variable, time_variable= &time_variable, ID_variable= &ID_variable)
	%pca(analysis_variable= &analysis_variable, ID_variable= &ID_variable)
	%fpcs_extraction(analysis_variable= &analysis_variable, ID_variable= &ID_variable, output_data_set= &output_data_set, FPC_cutoff= &FPC_cutoff)

%mend functional_pca;

*TEST;

%functional_pca(input_data_set= rec.ip_lhd_shot_analysis_truncated, analysis_variable= ISO_FREQPV, time_variable= Shot_duration, ID_variable= LotID)

%_eg_hidenotesandsource;

GOPTIONS NOACCESSIBLE;
%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROCESSFLOWNAME=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTPATHHOST=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;
%LET _SASPROGRAMFILEHOST=;

%_eg_restorenotesandsource;

;*';*";*/;quit;run;
ODS _ALL_ CLOSE;
