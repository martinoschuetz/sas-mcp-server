/*----------------------------------------------------------------------------------+
 |
 |   Title :  Metadata Advisor Code
 |
 |   DISCLAIMER;
 |   THIS INFORMATION IS PROVIDED BY SAS INSTITUTE INC. AS A
 |   SERVICE TO ITS USERS.  IT IS PROVIDED "AS IS".  THERE ARE NO
 |   WARRANTIES, EXPRESSED OR IMPLIED, AS TO MERCHANTABILITY OR
 |   FITNESS FOR A PARTICULAR PURPOSE REGARDING THE ACCURACY OF
 |   THE MATERIALS OR CODE CONTAINED HEREIN.
 |
 |   VERSION: 2.0 (27 August 2008)
 |
 |   AUTHOR: Karsten Winkler (Karsten.Winkler@sas.com)
 |
 |
 |   NOTES: Extracts column metadata of the incoming data set and
 |          creates metadata advisor SAS code setting the role, level,
 |          order, and report status of each variable. The preceding
 |          node must export a raw/training data set or a transaction
 |          data set.
 |
 |
 +-----------------------------------------------------------------------------------*/

/* ----------------------------------------------------------------------------------------- */
/* Set input parameters when used in SAS Code node. Comment out when used in extension node. */
/* ----------------------------------------------------------------------------------------- */

%let EM_PROPERTY_FILE_ENCODING = %STR(wlatin1);

/* ---------------------------------------------------------------- */
/* Do not edit the code below this line when used in SAS Code node! */
/* ---------------------------------------------------------------- */

%let TOOLTYPE = UTILITY;
%let DATANEEDED = Y;

/* ------------------------------------------------------------------- */
/* Begin: Contents of auxiliary macro file when used in extension node */
/* ------------------------------------------------------------------- */


/* Initialize property macro variables */
%macro metaadvc_set_properties;

  %em_checkmacro(name = EM_PROPERTY_FILE_ENCODING, global = Y, value = %STR(wlatin1));

%mend metaadvc_set_properties;

/* check for errors in parameters */
%macro metaadvc_checkerror;

  /* Check for errors related role of imported data set */
  %if (%eval(%length(&EM_IMPORT_TRANSACTION.)) eq 0) and 
  (%eval(%length(&EM_IMPORT_DATA.)) eq 0) %then %do;
    %let EMEXCEPTIONSTRING = ERROR;
    %put &em_codebar;
    %put *;
    %put ERROR: The preceding node must export a training/raw or transaction data set.;
    %put *;
    %put &em_codebar;
  %end;

%mend;

/* collect column metadata and create the corresponding SAS code */
%macro metaadvc_create_sas_code;

  data _null_;
    file PRINT;
    put 'When creating a new SAS Enterprise Miner data source using the data source wizard,';
    put 'click the "Show code" button in step 5 of 6 (column metadata), paste the generated';
    put 'metadata advisor code into the editor, and click the "Apply code" button to set';
    put 'the level, role, order, and report properties accordingly.';
    put ' ';
    put 'The following file on the SAS Enterprise Miner server comprises the metadata advisor';
    put 'code that describes the column metadata of all variables of the incoming data set:';
    put "&EM_USER_RESULT_SAS_FILE.";
    put ' ';
    put 'DISCLAIMER: THIS INFORMATION IS PROVIDED BY SAS INSTITUTE INC. AS A SERVICE TO ITS';
    put 'USERS. IT IS PROVIDED "AS IS". THERE ARE NO WARRANTIES, EXPRESSED OR IMPLIED, AS TO';
    put 'MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE REGARDING THE ACCURACY OF THE';
    put 'MATERIALS OR CODE CONTAINED HEREIN.';
  run;

  data work.metadata_advisor_sas_code;
    length line $1024;
    %if (%eval(%length(&EM_IMPORT_DATA.)) gt 0) %then %do;
      set &EM_IMPORT_DATA_CMETA;
    %end;
    %else %if (%eval(%length(&EM_IMPORT_TRANSACTION.)) gt 0) %then %do;
      set &EM_IMPORT_TRANSACTION_CMETA;
    %end;    
    line = "if trim(upcase(name)) eq upcase('" 
      || trim(upcase(name)) || "') then do; ";
    output; 
    line = "level='" || trim(upcase(level)) || "'; " 
      || "role='" || trim(upcase(role)) || "'; "
      || "order='" || trim(upcase(order)) || "'; "
      || "report='" || trim(upcase(report)) || "';";
    output;
    line = "end;";
    output;
  run;

  filename result "&EM_USER_RESULT_SAS_FILE.";
  data _null_;
    set work.metadata_advisor_sas_code;
    file result lrecl = 1024 encoding = "&EM_PROPERTY_FILE_ENCODING.";
    put line;
  run;
  filename result;

  /* garbage collection */
  proc datasets library = work nolist;
    delete metadata_advisor_sas_code;
  run;
  quit;

%mend metaadvc_create_sas_code;

/* ----------------------------------------------------------------- */
/* End: Contents of auxiliary macro file when used in extension node */
/* ----------------------------------------------------------------- */

%macro main;

  /* Uncomment when used in extension node */
  * filename temp catalog 'sashelp.emextkwr.metadvc_macros.source';
  * %include temp;
  * filename temp;

  /* Initialize property macro variables to ensure settings in a batch environment */
  %metaadvc_set_properties;

  /* Initialize the EMEXCEPTIONSTRING string and check for parameter errors */
  %em_checkerror;
  %metaadvc_checkerror;
  %if (%eval(%length(&EMEXCEPTIONSTRING.)) gt 0) %then %goto doendm;

  /* Register data sets and reports to be displayed in the Results window */
  %em_register(key = RESULT_SAS_FILE, type = FILE, extension = SAS);

  %em_report(key = RESULT_SAS_FILE, viewtype = output, autodisplay = Y, 
  block = Results, description = Metadata Advisor Code);

  /* collect column metadata and create the corresponding SAS code */
  %metaadvc_create_sas_code;
 
  /* goto target in case of error */
  %doendm:

%mend main;

%main;
