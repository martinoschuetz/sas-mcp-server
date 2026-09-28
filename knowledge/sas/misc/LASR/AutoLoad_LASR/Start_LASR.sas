 /*** START LASR SERVER *********************************************************/
 /* Purpose: To start LASR Server						*/
 /*          					 				*/
 /* Parameters:	No Parameter.							*/
 /*										*/
 /* Environment: On Windows SAS 9.4 VA 6.2 LASR SMP	   			*/
 /*										*/
 /* Author: Shatrughan Saxena							*/
 /* Email:  Shatrughan.Saxena@sas.com						*/
 /*										*/
 /* History:  Date | Remarks							*/
 /*		3rd October 2013 | First development.				*/
 /*******************************************************************************/

%let HOST_NAME=sasva.demo.sas.com; 											/* Change the hostname as per your VA setup if required */
%let LASR_START_PORT=10010;												/* Change the LASR Server's PORT Number if running on different port in your setup */
%let LASR_SIGFILE_PATH=D:\opt\sasinside\sasva\Lev1\AppData\SASVisualAnalytics6.2\VisualAnalyticsAdministrator\sigfiles;	/* Change LASR Server's SIGNER FILE path if different in your setup */
%let LASR_SIGN_URL=http://sasva.demo.sas.com:80/SASLASRAuthorization;							/* Change LASR Server's SIGNER URL if different in your setup */

%let _ENCODING=UTF-8;
%macro disablelisting;
   %if (&SYSSCP. eq WIN) %then %LET NULPATH=NUL;
   %else %LET NULPATH=/dev/null;
   /* Disable listing file output */
   proc printto print = "&NULPATH.";
   run;
%mend;
%disablelisting;

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
%statuscheckpoint;
/* Skip Next Step If We Have a Bad Status Code */
%macro codeBody;
   %GLOBAL LASTSTEPRC;
   %if %symexist(LASTSTEPRC) %then %do;
      %if %eval(&LASTSTEPRC. <= 4) %then %do;
      
         /* Start the single-machine LASR server process */
         
         libname ml sasiola startserver=(path="&LASR_SIGFILE_PATH.") host="&HOST_NAME." port=&LASR_START_PORT. signer="&LASR_SIGN_URL.";
         
      %end;
   %end;
%mend;
%codeBody;

%statuscheckpoint;
/* Skip Next Step If We Have a Bad Status Code */
%macro codeBody;
   %GLOBAL LASTSTEPRC;
   %if %symexist(LASTSTEPRC) %then %do;
      %if %eval(&LASTSTEPRC. <= 4) %then %do;
      
         /* Keep the SAS session up until SERVERTERM received */
         proc vasmp;
            serverwait port=&LASR_START_PORT.;
         quit;
      %end;
   %end;
%mend;
%codeBody;