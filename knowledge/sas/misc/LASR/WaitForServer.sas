%macro WaitForServer(
  URL=http://localhost:80/SASVisualAnalyticsHub
 ,Retries=10
 ,RetryWait=2
 ,Abort=No
 );
 %let Status=;
 %let Try=0;
 %do %while(&Try < &Retries AND &Status ne OK);
    %let Try=%eval(&Try+1);
    %IsServerReady(URL=&URL.);
    %let Status=&ServerStatus;
    %if &Status ne OK %then %do;
      %put NOTE: Server is not ready, (Attempt &try of &Retries), waiting &RetryWait Seconds before next attempt.;
      %let rc=%sysfunc(sleep(&RetryWait));
    %end;
 %end;
 %if &Status ne OK %then %do;
   %put ERROR: &URL. is not ready.;
   %if %upcase(&Abort) = YES %then %ABORT 12;
 %end;
%mend;
