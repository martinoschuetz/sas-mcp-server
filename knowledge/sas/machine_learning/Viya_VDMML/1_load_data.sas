/****************************************************************************/
/* This is the first in a series of examples provided to demonstrate the    */
/* use of SAS Visual Data Mining and Machine Learning procedures to compose */
/* a program that follows a standard machine learning process of            */
/* - loading data,                                                          */
/* - preparing the data,                                                    */
/* - building models, and                                                   */
/* - assessing and comparing those models                                   */
/*                                                                          */
/* The programs are written to execute in the CAS in-memory distributed     */
/* computing engine in the SAS environment.                                 */
/*                                                                          */
/* This first example showcases how to load local data into CAS             */
/****************************************************************************/

/****************************************************************************/
/* Setup and initialize for later use in the program                        */
/****************************************************************************/
/* Specify a libref for local data sets */
libname locallib '/opt/sasinside/DemoData';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;

/****************************************************************************/
/* Load data into CAS                                                       */
/*                                                                          */
/* The data set used for this workflow is anonymized bank data consisting   */
/* of observations taken on a large financial services firm's accounts.     */
/* Accounts in the data represent consumers of home equity lines of credit, */
/* automobile loans, and other types of short- to medium-term credit        */
/* instruments.  A campaign interval for the bank runs for half of a year,  */
/* denoting all marketing efforts that provide information about and        */
/* motivate the purchase of the bank's financial services products.         */
/*                                                                          */
/* - the bankraw data set is the original data in its raw form              */
/* - the bank data set is the resulting data set after applying appropriate */
/*   data cleansing                                                         */
/*                                                                          */
/* The target variable "b_tgt" quantifies account responses over the        */
/* current campaign season (1 for at least one purchase, 0 for no purchases)*/
/* A description of all variables can be found in the data dictionary for   */
/* this data set available in "BankData" in your File Shortcuts.            */
/*                                                                          */
/* For execution in the CAS engine, data must be loaded from the local      */
/* data set to a CAS table. This code first checks to see if the specified  */
/* CAS table exists and then loads data from local data sets in 2           */
/* different ways.  After executing this code, you will notice a new        */
/* "MYCASLIB" library reference under "Libraries" in the navigation panel   */
/* on the left side (note the special icon indicating it is a caslib).      */													 
/*                                                                          */
/****************************************************************************/
%if not %sysfunc(exist(mycaslib.bank_raw)) %then %do;

  /* You can load data using a "load" statement in PROC CASUTIL */
  proc casutil;
    load data=locallib.bank_raw casout="bank_raw";
  run;

%end;

%if not %sysfunc(exist(mycaslib.bank)) %then %do;
  
  /* You can also load data using a data step */
  data mycaslib.bank;
    set locallib.bank;
  run;	 

%end;
