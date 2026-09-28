%macro list_actions;

    cas casauto sessopts=(metrics=true);

    proc cas;
        session casauto;
        session.listSessions result=res1 ;
        saveresult res1 dataout=work.res1;
        run;
    quit;

    proc sql noprint;
        select UUID into :uuids separated by "|" from res1;
    quit;
    %let n=&sqlobs.;
    %put &=n. &=UUIDS.;

    %DO i=1 %TO &n.;
        %let UUID=%scan(&UUIDS., &i., "|");

        proc cas;
            session casauto;
            session.listactionq result=res / uuid="&UUID.";
            print res;
        quit;

        /*
        cas a uuid="&UUID.";
        cas a terminate;
         */
    %END;

    cas casauto terminate;
%mend list_actions;
%list_actions;
