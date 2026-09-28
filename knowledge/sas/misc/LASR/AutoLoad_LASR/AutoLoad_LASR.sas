 /*** AUTOLOAD TABLES TO LASR SERVER ********************************************************************/
 /* Purpose: To autoload all the tables registered on LASR Server					*/
 /*          					 							*/
 /* Parameters:	No Parameter.										*/
 /*													*/
 /* Environment: On Windows SAS 9.4 VA 6.2 LASR SMP	   						*/
 /*													*/
 /* Author: Shatrughan Saxena										*/
 /* Email: Shatrughan.Saxena@sas.com									*/
 /*													*/
 /* History:  Date | Remarks										*/
 /*		3rd October 2013 | First development.					  		*/
 /*******************************************************************************************************/

%let _ENCODING=UTF-8;

/* Change these settings as per your VA Server setup */

%let HOST_NAME=sasva.demo.sas.com; 									/* Change the hostname as per your VA setup if required */
%let META_REPOSITORY=Foundation; 									/* Change the repository as per your VA setup if required */
%let META_PORT=8561; 											/* Change the Metadata Port as per your VA setup if required */
%let META_ADM_USER=sasadm@saspw;									/* Change the Metadata Admin User Name as per your VA setup if required */
%let META_ADM_USER_PASS=Orion123;									/* Change the Password as per your VA setup if required */
%let META_VA_USER=sasdemo; 										/* Change the Metadata VA Admin User Name as per your VA setup if required */
%let META_VA_USER_PASS=Orion123; 									/* Change the Password VA Admin User as per your VA setup if required */
%let METADATA_LIB_NAME=DemoData;									/* Change the Metadata Library where you registered and loaded your datasets */
%let METADATA_LIB_LOC=D:\opt\sasinside\DemoData\TinyData;						/* Location where your datasets reside on operating system */
%let LASR_PORT=10010;											/* Change the LASR Server's PORT Number if running on different port in your setup */
%let LASR_SIGNER_URL=http://sasva.demo.sas.com:80/SASLASRAuthorization;					/* Change LASR Server's SIGNER URL if different in your setup */
%let REGISTER_TABLE_LIBRARY=/Products/SAS Visual Analytics Administrator/Visual Analytics LASR;		/* Library where tables will get Registerd. Please do not change unless you are very sure about this*/
%let REGISTER_TABLE_FOLDER=/Shared Data/LASR;								/* Location of Metadata folder where you registered the tables.*/


/* options mprint mlogic symbolgen; */
/* option sql_ip_trace=all;  */
options noconnectpersist;            
options noconnectwait;
options metaserver=&HOST_NAME.; 
options metaport=&META_PORT.; 
options metarepository=&META_REPOSITORY.; 
options metauser=&META_VA_USER.;
options metapass=&META_VA_USER_PASS.; 

/* ....... Please do not make any changes in DISABLELISTING Macro ......... */

%macro disablelisting;
 %if (&SYSSCP. eq WIN) %then %LET NULPATH=NUL;
   %else %LET NULPATH=/dev/null;
   /* Disable listing file output */
   proc printto print = "&NULPATH.";
   run;
%mend;
%disablelisting;

/* ....... Please do not make any changes in STATUS CHECKPOINT Macro ......... */

/* Status Checkpoint Macro */
%macro statuscheckpoint(maxokstatus=4, varstocheck=SYSERR SYSLIBRC );

   %GLOBAL LASTSTEPRC;
   %LET pos=1;
   %let var=notset;
   %let var=%SCAN(&varstocheck.,&pos.);
   %DO %WHILE ("&VAR." ne ""); 
      /* Retrieve the next return code to check */
	  %if (%symexist(&VAR.)) %then %do;
	     %let val=&&&VAR..;
	     %if (("&VAL." ne "") and %eval(&VAL. > &maxokstatus.)) %then %do;
		    %put FAIL = &VAR.=&VAL. / SYSCC=&SYSCC.;
           %let LASTSTEPRC=&VAL.;
		 %end;
	  %end;
	  %let pos = %eval(&pos.+1);
      %let var=%SCAN(&varstocheck.,&pos.);
   %END;
%mend;

/* ....... Please do not make any changes in REGISTER TABLE Macro ......... */

/* Register Table Macro */

%macro registertable( REPOSITORY=Foundation, REPOSID=, LIBRARY=, TABLE=, FOLDER=, TABLEID=, PREFIX= );

   %let REPOSARG=%str(REPNAME="&REPOSITORY.");
   %if ("&REPOSID." ne "") %THEN %LET REPOSARG=%str(REPID="&REPOSID.");

   %if ("&TABLEID." ne "") %THEN %LET SELECTOBJ=%str(&TABLEID.);
   %else                         %LET SELECTOBJ=%str(&TABLE.);

   %if ("&FOLDER." ne "") %THEN
      %PUT INFO: Registering &FOLDER./&SELECTOBJ. to &LIBRARY. library.;
   %else
      %PUT INFO: Registering &SELECTOBJ. to &LIBRARY. library.;

   proc metalib;
      omr (
         library="&LIBRARY." 
         &REPOSARG. 
          ); 
      %if ("&TABLEID." eq "") %THEN %DO;
         %if ("&FOLDER." ne "") %THEN %DO;
            folder="&FOLDER.";
         %end;
      %end;
      %if ("&PREFIX." ne "") %THEN %DO;
         prefix="&PREFIX.";
      %end;
      select ("&SELECTOBJ."); 
   run; 
   quit;

%mend;
%statuscheckpoint;

/* Skip Next Step If We Have a Bad Status Code */

%macro codeBody;

   %GLOBAL LASTSTEPRC;
 	%if %symexist(LASTSTEPRC) %then %do;      		
      		%if %eval(&LASTSTEPRC. <= 4) %then %do;	
		
		 /* This code is to generate the current date and time to be used inside the lable */ 
			data _null_;
					datevar=put(date(),weekdate29.);
					timevar=put(time(),timeampm19.);
					call symputx('MYDATE',datevar);
					call symputx('MYTIME',timevar);
			run;
			
		 /* Load into server */
		 /* Access the data */
		 /* Change this folder to your actual folder where your datasets reside on OS */

		 LIBNAME &METADATA_LIB_NAME. BASE "&METADATA_LIB_LOC.";
		 
		 /* Updating the datasets details from the physical library */
		 
		 proc metalib;
		      omr (libid="&METADATA_LIB_NAME." server="&HOST_NAME." port="&META_PORT." user="&META_ADM_USER." password="&META_ADM_USER_PASS.");
		 run;
		 
		 /* Reading the datasets details from the physical library */
		 
		 proc datasets lib= &METADATA_LIB_NAME. memtype=data;
		 run;

		 proc contents data= &METADATA_LIB_NAME.._ALL_ memtype=data out=table_name_lib noprint;
		 run;

		 proc sql noprint; /* Reading tables names from table_name_lib dataset  */
			select distinct upper(memname) into :TABLE_NAME separated by '|' from work.table_name_lib;
		 quit;

		 /* Non-colocated data source.  SASIOLA load. */
		 /* Access the data */
		 /* Change these settings as per your VA Server setup */

		 LIBNAME VALIBLA SASIOLA  TAG=hps  PORT=&LASR_PORT. HOST="&HOST_NAME."  SIGNER="&LASR_SIGNER_URL." ;

			/* This code is to run the load table multiple times for all the tables inside datasets folder defined above */ 

			%if %SYMEXIST(TABLE_NAME) %THEN %DO;
				%put NOTE: SCANNING &TABLE_NAME.;		/* &TABLE_NAME.  Variable contains the table name values read from the TABLE_LIST.txt file */
				%let pos=1;
				%let TBL=%SCAN(&TABLE_NAME.,&pos.,|);

				 %DO %WHILE ("&TBL." ne "");			/* &TBL.  Variable contains the table name values read from the TABLE_NAME variable */

					 data VALIBLA.&TBL. ( label="Loaded on &MYDATE. &MYTIME. from &METADATA_LIB_NAME..&TBL. by AutoLoad_LASR Script ran by &META_USER. user" );
					    set &METADATA_LIB_NAME..&TBL.;
					 run;

					 /* Synchronize table registration */

					 %registerTable(
					      LIBRARY=&REGISTER_TABLE_LIBRARY.
					    , REPOSITORY=&META_REPOSITORY.
					    , TABLE=&TBL.
					    , FOLDER=&REGISTER_TABLE_FOLDER.
					  ); 
									 /* LIBRARY: Change this location as per your VA setup if required */
									 /* REPOSITORY: Change the repository as per your VA setup if required */
									 /* TABLE: Please do not change anything here */
									 /* FOLDER: Change this locationas as per your VA setup if required */
					  %let POS=%eval(&pos.+1);
					  %let TBL=%SCAN(&TABLE_NAME.,&pos.,|);
				  %end;
			%end;
	       %end;
   	 %end;
%mend;
%codeBody;