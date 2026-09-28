/*------------------------------------------------------------*/
/* Copyright (c) 2013 by SAS Institute Inc, Cary NC 27511 USA */
/*                                                            */
/* Fix_Unformatted_Columns macro.                             */
/*                                                            */
/* Version 1 - 11APR2013                                      */
/* Version 2 - 24JUL2013                                      */
/*           Row sampling extended to BIGINT columns          */
/* version 3 - 09OCT2013                                      */
/*           Error checking                                   */
/* version 4 - 10apr2014 sasdxs                               */
/*           Added parm 'retest_existing_sasfmts'. Setting to */
/*           Y assures lengths are updated in the case where  */
/*           new longer data was appended to table since last */
/*           time this macro was run.                         */
/*                                                            */
/* Purpose - provide SAS format info as Hive table properties */
/*           Note that these properties apply only to string  */
/*           columns that contain character or datetime data. */
/*------------------------------------------------------------*/
options nonotes nosource noprintmsglist nomprint sastrace=off;
%macro Fix_Unformatted_Columns;
       /*------------------------------------------------------------*/
       /* Validate input parameters.                                 */
       /*------------------------------------------------------------*/
       %if ((%upcase(&check_for_datetimes) != %str(Y)) & (%upcase(&check_for_datetimes) != %str(N)))
           %then %do;
                 %put The value specified for CHECK_FOR_DATETIMES is invalid. Valid values are Y/N.;
                 %put;
                 %return;
                 %end;
 
       /*------------------------------------------------------------*/
       /* For datetime columns set the limit of records to examine.  */
       /*------------------------------------------------------------*/
       %if (&limit = -1 or &limit = %str())
           %then %let limit = %str();
           %else %if ((&limit < -1) or (&limit = 0))
                     %then %do;
                           %put The value specified for LIMIT is invalid. Valid values are -1, NULL, <number > 0>.;
                           %put;
                           %return;
                           %end;
                     %else %let limit = %str(LIMIT &limit);
 
       /*------------------------------------------------------------*/
       /* Check whether we are running in simulate mode...           */
       /*------------------------------------------------------------*/
       %if ((%upcase(&simulate) ne %str(Y)) and (%upcase(&simulate) ne %str(N)))
           %then %do;
                 %put The value specified for SIMULATE is invalid. Valid values are Y/N.;
                 %put;
                 %return;
                 %end;
 
       /*------------------------------------------------------------*/
       /* Check whether we retest/reset columns that already have a  */
       /* SASFMT property set.                                       */
       /*------------------------------------------------------------*/
       %if ((%upcase(&retest_existing_sasfmts) != %str(Y)) & (%upcase(&retest_existing_sasfmts) != %str(N)))
           %then %do;
                 %put The value specified for RETEST_EXISTING_SASFMTS is invalid. Valid values are Y/N.;
                 %put;
                 %return;
                 %end;
 
       /*------------------------------------------------------------*/
       /* Build a list of objects to examine using the search pattern*/
       /* provided.                                                  */
       /*------------------------------------------------------------*/
       proc sql noprint;
            connect to hadoop &connection_string;
            create table objects_to_examine as
            select * from connection to hadoop (show tables &tabname);
 
            select count(*)
              into :tabcount
              from objects_to_examine;
 
            %let tabcount=%trim(&tabcount);
 
            %if &tabcount > 0
                %then %do;
                      select *
                        into :table_name1-:table_name&tabcount
                        from objects_to_examine;
                %end;
                %else %do;
                      /*------------------------------------------------------------*/
                      /* Object list is empty.                                      */
                      /*------------------------------------------------------------*/
                      quit;
                      %put -------------------------------------------------------------------------------------------------;
                      %put No objects found;
                      %put;
                      %return;
                %end;
       quit;
 
       %let objects_with_unformatted_columns = 0;
 
       /*------------------------------------------------------------*/
       /* Examine the list of objects.                               */
       /*------------------------------------------------------------*/
       %do table_number=1 %to &tabcount;
           %put -------------------------------------------------------------------------------------------------;
           %put Processing object "&&table_name&table_number"...;
           %put;
 
           proc sql;
                connect to hadoop &connection_string;
                create table describe_formatted as
                select * from connection to hadoop (describe formatted &&table_name&table_number);
           quit;
 
           /*------------------------------------------------------------*/
           /* Get the list of formatted columns for the object.          */
           /*------------------------------------------------------------*/
           data SASFMTs;
                length col_name $256;
                set describe_formatted;
                where index(data_type, "SASFMT") > 0;
                col_name=substr(data_type, 8);
           run;
 
           /*------------------------------------------------------------*/
           /* Get the list of string and bigint columns for the object.  */
           /*------------------------------------------------------------*/
           data OBJECT_COLUMNs;
                length col_name $256;
                retain seeing_columns 0;
                set describe_formatted;
 
                if (substr(col_name,1,10)="# col_name")
                   then seeing_columns = 1;
                   else if (substr(col_name,1,1)="#")
                           then seeing_columns = 0;
                           else if (
                                    (seeing_columns & substr(data_type,1,6) = "string" & substr(col_name,1,1) ^= ' ') or
                                    (seeing_columns & substr(data_type,1,6) = "bigint" & substr(col_name,1,1) ^= ' ')
                                   )
                                   then output;
 
                if (col_name = "Table Type:")
                   then call symput('object_type', data_type);
           run;
 
           %let object_type = %trim(&object_type);
 
           %if &object_type = %str(VIRTUAL_VIEW)
               %then %let object=%str(VIEW);
               %else %let object=%str(TABLE);
 
           /*------------------------------------------------------------*/
           /* Determine which columns don't have a format.               */
           /*------------------------------------------------------------*/
           proc sql noprint;
                create table noSASFMTs as
                select col_name, data_type
                  from OBJECT_COLUMNs
           /*------------------------------------------------------------*/
           /*                   10apr2014 sasdxs                         */
           /* If 'retest_existing_sasfmts' is YES, retest and reset      */
           /* existing SASFMT properties.                                */
           /*------------------------------------------------------------*/
           %if (%upcase(&retest_existing_sasfmts) = %str(N))
           %then %do;
                 where col_name not in (select col_name from SASFMTs)
           %end;
                 ;
 
                select count(*)
                  into :count
                  from noSASFMTs;
 
                %let count=%trim(&count);
 
                %if &count > 0
                    %then %do;
                          select col_name, data_type
                            into :colname1-:colname&count,
                                 :datatype1-:datatype&count
                            from noSASFMTs;
 
                          /*------------------------------------------------------------*/
                          /* Find out MAX length for all unformatted STRING columns and */
                          /* set the table properties accordingly.                      */
                          /*------------------------------------------------------------*/
                          proc sql noprint;
                               connect to hadoop &connection_string;
 
                               /*------------------------------------------------------------*/
                               /* LIMIT does not influence the optimizer in that it does not */
                               /* limit the number of rows that are considered for execution */
                               /* upfront. It only applies to the end result to simply limit */
                               /* the rows that are returned to the application.             */
                               /* To be able to leverage its efficacy, when LIMIT is greater */
                               /* than 0, a "temporary" database table is created containing */
                               /* only the number of rows we want to analyze. The same table */
                               /* is dropped at the end of the process.                      */
                               /* If, for any reason, the temporary table cannot be created, */
                               /* the original one is used in its place.                     */
                               /*------------------------------------------------------------*/
                               %let temporary = %str();
                               %if (&limit ne %str())
                                   %then %do;
                                         %let temporary = %str(_TEMPORARY);
                                         execute (DROP TABLE `&&table_name&table_number&temporary`) by hadoop;
                                         execute (CREATE TABLE `&&table_name&table_number&temporary` AS SELECT * FROM `&&table_name&table_number` &limit) by hadoop;
                                         %if (%eval(&sqlrc) = 0)
                                             %then %let table_to_analyze = %str(&&table_name&table_number&temporary);
                                             %else %do;
                                                   %let table_to_analyze = %str(&&table_name&table_number);
                                                   %let temporary = %str();
                                                   %end;
                                   %end;
                                   %else %do;
                                         %let table_to_analyze = %str(&&table_name&table_number);
                                   %end;
 
                               select * into %do i=1 %to %eval(&count) - 1; :maxlen&i, %end; :maxlen&count
                                 from connection to hadoop (
                               select %do i=1 %to %eval(&count) - 1; COALESCE(MAX(LENGTH(`&&colname&i`)),0), %end;
                                      COALESCE(MAX(LENGTH(`&&colname&count`)),0)
                                 from `&table_to_analyze`);
 
                               %do i=1 %to %eval(&count);
                                   %let maxlen&i = %trim(&&maxlen&i);
                                   %let bad_time_values_count = -1;
                                   %let bad_date_values_count = -1;
                                   %let bad_datetime_values_count = -1;
 
                                   /*------------------------------------------------------------*/
                                   /* Want to check if the columns contains datetime values?     */
                                   /*                                                            */
                                   /* 1. Check for time values                                   */
                                   /* 2. Check for date values                                   */
                                   /* 3. Check for datetime values                               */
                                   /*------------------------------------------------------------*/
                                   %if (%upcase(&check_for_datetimes) = %str(Y) & (&&maxlen&i > 0))
                                       %then %do;
                                             %if (&&maxlen&i = 8)
                                                 %then %do;
                                                       select * into :bad_time_values_count from connection to hadoop (
                                                       select count(*)
                                                         from `&table_to_analyze`
                                                        where substr(`&&colname&i`,3,1) <> ':'
                                                           or substr(`&&colname&i`,6,1) <> ':'
                                                           or cast(substr(`&&colname&i`,1,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,1,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,1,2) as smallint) > 24
                                                           or cast(substr(`&&colname&i`,4,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,4,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,4,2) as smallint) > 60
                                                           or cast(substr(`&&colname&i`,7,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,7,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,7,2) as smallint) > 60);
                                                       %end;
 
                                             %if (&&maxlen&i = 10)
                                                 %then %do;
                                                       select * into :bad_date_values_count from connection to hadoop (
                                                       select count(*)
                                                         from `&table_to_analyze`
                                                        where substr(`&&colname&i`,5,1) <> '-'
                                                           or substr(`&&colname&i`,8,1) <> '-'
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) is null
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) > 9999
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) > 12
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) > 31);
                                                       %end;
 
                                             %if (&&maxlen&i = 19)
                                                 %then %do;
                                                       select * into :bad_datetime_values_count from connection to hadoop (
                                                       select count(*)
                                                         from `&table_to_analyze`
                                                        where substr(`&&colname&i`,5,1) <> '-'
                                                           or substr(`&&colname&i`,8,1) <> '-'
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) is null
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,1,4) as smallint) > 9999
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,6,2) as smallint) > 12
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) < 1
                                                           or cast(substr(`&&colname&i`,9,2) as smallint) > 31
                                                           or substr(`&&colname&i`,11,1) <> ' '
                                                           or substr(`&&colname&i`,14,1) <> ':'
                                                           or substr(`&&colname&i`,17,1) <> ':'
                                                           or cast(substr(`&&colname&i`,12,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,12,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,12,2) as smallint) > 24
                                                           or cast(substr(`&&colname&i`,15,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,15,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,15,2) as smallint) > 60
                                                           or cast(substr(`&&colname&i`,18,2) as smallint) is null
                                                           or cast(substr(`&&colname&i`,18,2) as smallint) < 0
                                                           or cast(substr(`&&colname&i`,18,2) as smallint) > 60);
                                                       %end;
 
                                             /*------------------------------------------------------------*/
                                             /* All examined the dates seem valid.                         */
                                             /*------------------------------------------------------------*/
                                             %if &bad_time_values_count = 0
                                                 %then %do;
                                                       %if (%upcase(&simulate) = %str(N))
                                                           %then %do;
                                                                 execute (ALTER &object `&&table_name&table_number` SET
                                                                 TBLPROPERTIES ("SASFMT:&&colname&i"="TIME8.)")) by hadoop;
                                                                 %end;
 
                                                       %put Column `&&colname&i` Format TIME8.;
                                                       %end;
                                                 %else %if &bad_date_values_count = 0
                                                           %then %do;
                                                                 %if (%upcase(&simulate) = %str(N))
                                                                     %then %do;
                                                                           execute (ALTER &object `&&table_name&table_number` SET
                                                                           TBLPROPERTIES ("SASFMT:&&colname&i"="DATE10.)")) by hadoop;
                                                                           %end;
 
                                                                 %put Column `&&colname&i` Format DATE10.;
                                                                 %end;
                                                           %else %if &bad_datetime_values_count = 0
                                                                 %then %do;
                                                                       %if (%upcase(&simulate) = %str(N))
                                                                           %then %do;
                                                                                 execute (ALTER &object `&&table_name&table_number` SET
                                                                                 TBLPROPERTIES ("SASFMT:&&colname&i"="DATETIME20.)")) by
                                                                                 hadoop;
                                                                                 %end;
 
                                                                       %put Column `&&colname&i` Format DATETIME20.;
                                                                       %end;
                                                                 %else %do;
                                                                       %if (%upcase(&simulate) = %str(N))
                                                                           %then %do;
                                                                                execute (ALTER &object `&&table_name&table_number` SET
                                                                                TBLPROPERTIES ("SASFMT:&&colname&i"="CHAR(&&maxlen&i)"))
                                                                                by hadoop;
                                                                                 %end;
 
                                                                       %put Column `&&colname&i` Format CHAR(&&maxlen&i);
                                                                       %end;
                                       %end;
                                   %else %if &&maxlen&i > 0
                                             %then %do;
                                                   %if (%upcase(&simulate) = %str(N))
                                                       %then %do;
                                                             %if (&&datatype&i = %str(bigint))
                                                                 %then %do;
                                                                       execute (ALTER &object `&&table_name&table_number` SET
                                                                       TBLPROPERTIES ("SASFMT:&&colname&i"="CHAR(20)")) by hadoop;
                                                                       %end;
                                                                 %else %do;
                                                                       execute (ALTER &object `&&table_name&table_number` SET
                                                                       TBLPROPERTIES ("SASFMT:&&colname&i"="CHAR(&&maxlen&i)")) by hadoop;
                                                                       %end;
                                                             %end;
 
                                                   %put Column `&&colname&i` Format CHAR(&&maxlen&i);
                                                   %end;
                                             %else %if &&maxlen&i = 0
                                                       %then %put Column `&&colname&i` NULL - Table property not set;
                               %end;
 
                               %if (&temporary = %str(_TEMPORARY))
                                   %then %do;
                                         execute (DROP TABLE `&table_to_analyze`) by hadoop;
                                         %end;
 
                               %put;
                               %put Unformatted columns found : &count;
                          quit;
                          %put;
                          %let objects_with_unformatted_columns = %eval(&objects_with_unformatted_columns + 1);
                    %end;
                    /*------------------------------------------------------------*/
                    /* No unformatted columns found.                              */
                    /*------------------------------------------------------------*/
                    %else %do;
                          %put No unformatted columns found for object "&&table_name&table_number";
                          %put;
                    %end;
           quit;
       %end;
       %put -------------------------------------------------------------------------------------------------;
       %put Number of objects examined                 : &tabcount;
       %put Number of objects with unformatted columns : &objects_with_unformatted_columns;
       %if (%upcase(&simulate) = %str(Y))
           %then %do;
                 %put Running in simulated mode;
                 %end;
       %let limit = %str();
%mend;
 
/*----------------------------------------------------------*/
/* Macro parameters:                                        */
/*                                                          */
/* connection_string:                                       */
/* Specifies the connection options used to connect to the  */
/* Hadoop server.                                           */
/*                                                          */
/* tabname:                                   (default '*') */
/* Specifies the object name or pattern to be used to search*/
/* for objects with unformatted string columns. Always wrap */
/* the option value in single quotes.                       */
/* The values of tablename give you some flexibility over   */
/* which Hive objects are processed.                        */
/*                                                          */
/* For example:                                             */
/*                                                          */
/* --- tabname ---  --- Action in Hive -------------------- */
/*    '*tab*'       Process all tables and views that have  */
/*                  the string "tab" as part of their name. */
/*    'tabpp'       Process the Hive table/view "tabpp".    */
/*    '*'           Process all Hive tables and views that  */
/*                  are accessible from this connection.    */
/*                                                          */
/* check_for_datetimes:                       (default 'N') */
/* Whether or not to check if the column contains datetime  */
/* values depending on the length of its content:           */
/*                                                          */
/* Column content length  Check for                         */
/* ---------------------  ---------------                   */
/* 8                      Time values                       */
/* 10                     Date values                       */
/* 19                     Datetime values                   */
/*                                                          */
/* The format of the date time values is assumed to be ANSI */
/* ISO standard:                                            */
/*                                                          */
/* TIME     HH:MM:SS                                        */
/* DATE     YYYY-MM-DD                                      */
/* DATETIME YYYY-MM-DD HH:MM:SS                             */
/*                                                          */
/* limit:                                     (default -1)  */
/* It allows for row sampling by analizying a limited number*/
/* of rows instead of scanning the whole table.This is done */
/* by copying the rows to analyze to a new temporary table  */
/* that is dropped once the analysis is over.               */
/* By default, the entire table is analyzed.                */
/*                                                          */
/* simulate:                                                */
/* For datetime values checking,it allows to limit the rows */
/* to sample.No value or a value of -1 results in the whole */
/* table getting scanned.                                   */
/*                                                          */
/* retest_existing_sasfmts:                                 */
/* Setting to Y assures lengths are updated in the case     */
/* where new longer data was appended to table since last   */
/* time this macro was run.                                 */
/*----------------------------------------------------------*/
%let connection_string=%str((server=<server> user=<id> pwd=<password>));
%let tabname=%str('<table name or pattern>');
%let check_for_datetimes=%str(y|n);
%let limit=<value > 0 | NULL | -1>;
%let simulate=%str(y|n);
%let retest_existing_sasfmts=%str(y|n);
 
/*----------------------------------------------------------*/
/* Call the macro.  Make sure you entered connection and    */
/*                  tabname info above                      */
/*----------------------------------------------------------*/
%Fix_Unformatted_Columns;
