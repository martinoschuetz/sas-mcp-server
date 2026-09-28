/**************************************************************/
/** ENTERPRISE MINER PROJECT CONVERSION:Cross host and bits  **/
/**************************************************************/

/********************************************************************
 * EM_MigrateProject macro
 * THis macro prepares or converts Enterprise Miner project's files
 * to a portable format that can be moved to a new system and restored
 * or reconstituted in a form compatible with the new system.
 *
 * SYNTAX:
 * %EM_MigrateProject(
 *    Action= <PREPARE|RESTORE>, - Required
 *    RootPath= <projectpath>, - Required absolute project path
 *    CLEAN= <OFF|ON>, - Optional remove processed files
 *    VERBOSE=<ON|OFF> - Optional
 *    INCVIEWS=<OFF|ON> - optional include data views in processing.
 *    );
 *
 * USAGE:
 * First prepare or convert the project to a portable format
 *
 *   %EM_MigrateProject(Action=PREPARE ,RootPath=C:\MyOldFiles\EMProj\Test1 );
 *
 * Then move the whole folder (Test1) to the new system and run
 * the macro on the new system to restore or convert the project
 * files to a form compatable with the new system. For example:
 *
 *   %EM_MigrateProject(Action=RESTORE ,RootPath=C:\MyNewFiles\OldEMProj\Test1 );
 *
 *******************************************************************/


 %GLOBAL _EM_LOAD_EM_MODELPROPS;
 %GLOBAL _EM_PATHLEN;
 %GLOBAL _EM_ProjRoot;
 %GLOBAL _EM_Migrate_WARN;
 %GLOBAL _EM_ProjMigrate_Log;
 %GLOBAL _EM_TRACE;

%Macro EM_MigrateProject(
                 Action=       /* Required - PREPARE or RESTORE */
                ,RootPath=     /* Required - Absolute path for project folder */
                ,CLEAN=OFF     /* Optional - ON = deletes PREPAREed files */
                ,VERBOSE=OFF   /* Optional - ON = NOTES on */
                ,INCVIEWS=OFF  /* Optional - ON = includes data views */
                );
   /* initializations */
   %LET SYSCC = 0;
   %LET _EM_Migrate_WARN = 0;

   %IF %symexist(_EM_PATHLEN) %THEN %DO;
        %IF %EVAL(&_EM_PATHLEN < 256) %THEN  %LET _EM_PATHLEN = 256;
   %END;
   %ELSE %LET _EM_PATHLEN = 32767; /* default max string len */

   /* Check Parameters */
   /* valid root path required */
   %IF (("&RootPath" = "") or (%LENGTH(%SUPERQ(RootPath))<=0))  %THEN %DO;
      %PUT ERROR: EM_MigrateProject: parameter ROOTPATH must be set to project file path.;
      %GOTO ERROREXIT;
   %END;
   /* check for path existance */
   %LET filrf=testdir;
   %LET rc =%SYSFUNC(filename(filrf,"&RootPath"));
   %LET did=%SYSFUNC(dopen(&filrf));
   %IF (%EVAL(&did <= 0 )) %THEN %DO;
      %PUT ERROR: EM_MigrateProject: parameter ROOTPATH must be set to a valid project file path.;
      %GOTO NOROOT;
   %END;
   %LET rc=%SYSFUNC(dclose(&did));
   /* save path for log file */
   %LET _EM_ProjRoot = &RootPath;

   /* valid action required */
   %LET Action = %upcase(&Action);
   %IF (&Action ^= PREPARE) and (&Action ^= RESTORE) %THEN %DO;
      %PUT ERROR: EM_MigrateProject: parameter ACTION must be set to PREPARE or RESTORE.;
      %GOTO ERROREXIT;
   %END;

   /* option to compress size by deleteing un-needed files */
   %LET CLEAN = %upcase(&CLEAN);
   %IF (&CLEAN ^= ON) and (&CLEAN ^= OFF) %THEN %DO;
      %PUT ERROR: EM_MigrateProject: invalid option value for CLEAN, must be set to ON or OFF.;
      %GOTO ERROREXIT;
   %END;

   /* option to reduce log output */
   %LET VERBOSE = %upcase(&VERBOSE);
   %IF (&VERBOSE ^= ON) and (&VERBOSE ^= OFF) %THEN %DO;
      %PUT ERROR: EM_MigrateProject: invalid option value for VERBOSE, must be set to ON or OFF.;
      %GOTO ERROREXIT;
   %END;

   /* option to include data views in migration */
   %LET INCVIEWS = %upcase(&INCVIEWS);
   %IF (&INCVIEWS ^= ON) and (&INCVIEWS ^= OFF) %THEN %DO;
      %PUT ERROR: EM_MigrateProject: invalid option value for INCVIEWS, must be set to ON or OFF.;
      %GOTO ERROREXIT;
   %END;

   /* Start log file */
                               /* Save log name */
   %LET _EM_ProjMigrate_Log = &_EM_ProjRoot&_dsep.EMProj&Action.Log.txt;

                               /* clear old log */
   %IF %sysfunc(fileexist("&_EM_ProjMigrate_Log")) %THEN
       %EM_MigrateProject_DeleteFile(&_EM_ProjMigrate_Log);

   Filename logfile "&_EM_ProjMigrate_Log";

                               /* get time stamp */
   %LET fmt = datetime21.2;
   %LET When = %SYSFUNC( DATETIME(), &fmt );
                                /* first log entry */
   %EM_MigrateProject_MigrateLog(MSG= EM_MigrateProject: V4.8 Started &When);

   /* recored parmeters */
   %EM_MigrateProject_MigrateLog(MSG= RootPath = &RootPath);
   %EM_MigrateProject_MigrateLog(MSG= Action = &Action);
   %EM_MigrateProject_MigrateLog(MSG= CLEAN = &CLEAN);
   %EM_MigrateProject_MigrateLog(MSG= VERBOSE = &VERBOSE);
   %EM_MigrateProject_MigrateLog(MSG= INCVIEWS = &INCVIEWS);

   /* save current session options */
   Proc OPTSave OUT=WORK._MigrateOpts; Run;

   %LET _EM_TRACE = %upcase(&_EM_TRACE);
   %IF ("&_EM_TRACE" = "ON") %THEN %DO;
      %LET VERBOSE = ON;
      Options Mprint Mlogic;
   %END;
   %ELSE %DO;
      %LET _EM_TRACE = OFF;
      Options NOMprint NOMlogic;
   %END;

   %IF ("&VERBOSE" = "ON") %THEN
      %STR(Options NOTES SOURCE SOURCE2;);
   %ELSE
      %STR(Options NONOTES NOSOURCE NOSOURCE2;);

   /* check for EMProps availability */
   %EM_MigrateProject_LoadEMProps;

   %PUT ;
   %EM_MigrateProject_MigrateLog(MSG= Creating project file list...);
   /* List all files and sub-directories in the file hierarchy */
   %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

   %IF &SYSCC ^= 0 %THEN %ABORT CANCEL;
   %IF &SYSERR ^= 0 %THEN %ABORT CANCEL;
   %EM_MigrateProject_MigrateLog(MSG=Creating project file list completed RC= &SYSCC.);

   /*---------------------------------------------------------------
    * Preparing project
    *---------------------------------------------------------------*/
   %IF (&Action=PREPARE) %THEN %DO;

      %PUT ;
      /* save project file type and path data set in root as Prepared */
      %EM_MigrateProject_MigrateLog(MSG= Saving project content data...);
      %EM_MigrateProject_MigrateLog(MSG= See &RootPath&_dsep.Prepared.sas7bdat);
      Libname PRJ "&RootPath";
      Data PRJ.Prepared;
      Set EM_Proj;
         Keep Type Path;
      Run;
      %EM_MigrateProject_MigrateLog(MSG=Saving project content data completed RC= &SYSCC.);
      %PUT ;
      %IF (&_EM_Load_em_modelprops = 1) %THEN %DO;
         %EM_MigrateProject_MigrateLog(MSG= Saving project data requirements...);
         %EM_MigrateProject_MigrateLog(MSG= See &RootPath&_dsep.LibData.sas7bdat);

         %EM_MigrateProject_DataMap(ProjMeta=EM_Proj, Outdata=PRJ.LibData);
         %EM_MigrateProject_MigrateLog(MSG=Saving project data requirements completed RC = &SYSCC.);
      %END;
      %ELSE %DO;
         %LET SYSCC = 1;
         %EM_MigrateProject_MigrateLog(WMSG=Unable to Save project data requirements RC = &SYSCC);
      %END;
      %IF  (&SYSCC ^= 0) %THEN %LET _EM_Migrate_WARN = 1;

      Libname PRJ CLEAR;

      %IF (&INCVIEWS=ON) %THEN %DO;
         /* Prepare project data views */
         %PUT ;
         %EM_MigrateProject_MigrateLog(MSG=Preparing data views...);
         %EM_MigrateProject_PrepViews(ProjMeta=EM_Proj);
         %IF %EVAL(&SYSCC ^= 0) %THEN %LET _EM_Migrate_WARN = 1;
         %EM_MigrateProject_MigrateLog(MSG=Preparing data views completed RC= &SYSCC.);
      %END;

      /* Prepare Project text */
      %PUT ;
      %EM_MigrateProject_MigrateLog(MSG=Preparing text files...);
      /* Get project file list with prepared views and text files */
      %IF (&VERBOSE = ON) %THEN %DO;
         %PUT ;
         %PUT Adding prepared view text to project file list.;
      %END;
      %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

      %EM_MigrateProject_PrepTxt(ProjMeta=EM_Proj);
      %EM_MigrateProject_MigrateLog(MSG=Preparing text files completed RC= &SYSCC.);
      %IF %EVAL(&SYSCC ^= 0) %THEN %GOTO ERROREXIT;

      /* Prepare project catalogs */
      %PUT ;
      %EM_MigrateProject_MigrateLog(MSG=Preparing SAS catalogs...);
       /* List all files and sub-directories including the new _trantxt catalogs */
      %IF (&VERBOSE = ON) %THEN %DO;
         %PUT ;
         %PUT Adding prepared text files to project file list.;
      %END;
      %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

      %EM_MigrateProject_PrepCat(Projmeta=EM_Proj);
      %IF %EVAL(&SYSCC ^= 0) %THEN %GOTO ERROREXIT;
      %EM_MigrateProject_MigrateLog(MSG=Preparing SAS catalogs completed RC = &SYSCC.);

   %END; /* end prep step */

   /*---------------------------------------------------------------
    * Restoring project
    *---------------------------------------------------------------*/
   %IF (&Action=RESTORE) %THEN %DO;
      /* save project file type and path data set in root as Restored */
      Libname PRJ "&RootPath";
      Data PRJ.Restored;
      Set EM_Proj;
         Keep Type Path;
      Run;
      Libname PRJ CLEAR;
      %PUT ;
      %EM_MigrateProject_MigrateLog(MSG=Restoring SAS catalogs...);

      /* restore all SAS catalogs */
      %EM_MigrateProject_RestoreCats(Projmeta=EM_Proj);
      %IF %EVAL(&SYSCC ^= 0) %THEN %DO;
         %EM_MigrateProject_MigrateLog(MSG=Restoring SAS catalogs failed RC= &SYSCC.);
         %LET _EM_Migrate_WARN = &SYSCC;
         %GOTO ERROREXIT;
      %END;
      %EM_MigrateProject_MigrateLog(MSG=Restoring SAS catalogs completed RC= &SYSCC.);

      /* convert all SAS data sets to local format */
      %PUT ;
      %EM_MigrateProject_MigrateLog(MSG=Restoring SAS data sets...);
      %EM_MigrateProject_RestoreData(Projmeta=EM_Proj);
      %IF %EVAL(&SYSCC ^= 0) %THEN %DO;
         %EM_MigrateProject_MigrateLog(MSG=Restoring SAS data sets RC= &SYSCC.);
         %LET _EM_Migrate_WARN = &SYSCC;
         %GOTO ERROREXIT;
      %END;
      %EM_MigrateProject_MigrateLog(MSG=Restoring SAS data sets completed RC= &SYSCC.);

      %PUT;
      %EM_MigrateProject_MigrateLog(MSG=Restoring text files...);
      %IF (&VERBOSE = ON) %THEN %DO;
         %PUT ;
         %PUT Add restored files to project file list.;
      %END;
      %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

      /* find _trantxt catalogs and restore text files */
      %EM_MigrateProject_RestoreText(Projmeta=EM_Proj);
      %IF %EVAL(&SYSCC ^= 0) %THEN %DO;
         %LET _EM_Migrate_WARN = &SYSCC;
         %GOTO ERROREXIT;
      %END;
      %EM_MigrateProject_MigrateLog(MSG= Restoring text files completed RC= &SYSCC.);

      %IF (&VERBOSE = ON) %THEN %DO;
         %PUT ;
         %PUT Add restored files to project file list.;
      %END;
      %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

      %IF (&INCVIEWS=ON) %THEN %DO;
         /* process data views */
         %PUT;
         %EM_MigrateProject_MigrateLog(MSG=Restoring SAS data views...);

         /* check for required libnames and data sets */
         Libname PRJ "&RootPath";
         %EM_MigrateProject_CheckDataMap(DataMap=PRJ.LibData);
         /* Warn if external data is incomplete */
         %IF %EVAL(&SYSCC ^= 0) %THEN %DO;
            %EM_MigrateProject_MigrateLog(WMSG=
             Without access to original data some project data views may not restore);
             %LET _EM_Migrate_WARN = &SYSCC;
         %END;

         /* process all the .stc files in workspace and flow order */
         %EM_MigrateProject_RestoreViews(Projmeta=EM_Proj);
         %IF %EVAL(&SYSCC ^= 0) %THEN %DO;
            %LET _EM_Migrate_WARN = &SYSCC;
         %END;

         Libname PRJ CLEAR;

         %EM_MigrateProject_MigrateLog(MSG=Restoring SAS data views competed RC= &SYSCC.);
      %END; /* end INCVIEWS  */
   %END; /* end When Restoring */

   /* libname for migration results data sets */
   %IF ("&VERBOSE" = "ON") %THEN %DO;
      Libname PRJ "&RootPath";
   %END;

   %IF (&CLEAN = ON) AND (&_EM_Migrate_WARN = 0) %THEN %DO;
       %EM_MigrateProject_GetFileInfo(RootPath=&RootPath,Projmeta=EM_Proj);

            /* Delete un-needed files from project */
       %EM_MigrateProject_CleanProj(Projmeta=EM_Proj, Action= &Action );
   %END;

   /* set end message */
   %IF (&Action=PREPARE) %THEN
      %LET EndMsg = NOTE: EM_MigrateProject: preparation completed.;
   %ELSE
      %LET EndMsg = NOTE: EM_MigrateProject: restoration completed.;

   %GOTO EXIT;
%ERROREXIT:
   %IF (&Action=PREPARE) %THEN
      %LET EndMsg = ERROR: EM_MigrateProject: preparation failed.;
   %ELSE
      %LET EndMsg = ERROR: EM_MigrateProject: restoration failed.;


%EXIT:
  /* reset any SAS options that may have changed */
   %IF %SYSFUNC(exist(WORK._MigrateOpts)) %THEN %DO;
      Proc OPTLoad DATA=_MigrateOpts; Run;
      Proc Delete Data=WORK._MigrateOpts; Run;
   %END;

   %PUT ;
   %EM_MigrateProject_MigrateLog(MSG= &EndMsg);

   /* end with warning if any issues detected */
   %IF (%EVAL(&_EM_Migrate_WARN > 0)) %THEN
      %EM_MigrateProject_MigrateLog(WMSG= Check the log for issues that occured during the migration process);
%NOROOT:;
   %LET SYSCC = &_EM_Migrate_WARN;
%MEND EM_MigrateProject;


/*******************************************************************
 * EM_MigrateProject_GetFileInfo - produces a data set with all the file
 *  system information for the project tree that is required for
 *  Enterprise Miner project migration.
 * RootPath - the absolute path for the project root directory
 * ProjMeta - name of work data set to contain the project info.
 ********************************************************************/
%Macro EM_MigrateProject_GetFileInfo(RootPath=,ProjMeta=_EMProj);

   %IF %symexist(_EM_PATHLEN) %THEN %DO;
        %IF %EVAL(&_EM_PATHLEN < 256) %THEN  %LET _EM_PATHLEN = 256;
   %END;
   %ELSE %LET _EM_PATHLEN = 32767; /* default max string len */


   /* start file hierarchy data set with target dir */
   Data &ProjMeta;
      Length Type $ 5;
      Length Path RelPath Location $ &_EM_PATHLEN;
      Length Name $ 256;

      Type = "root";         /* entry type root, dir or file       */
      Path = "&RootPath";    /* entry path (absolute)              */
      Name = scan(Path,-1,"&_dsep");
      Location = ' ';        /* path without filename      */
      Status = 0;            /* flags processing state 0 1 2       */
      Action = 0;            /* flags actionable files */
      Fcount = 0;            /* count of actionable files          */
      RelPath = ' ';         /* relative path from root */

      call symput('RootName', Name);
   Run;
   %IF ("&_EM_TRACE" = "ON") %THEN
      %PUT Searching project ...;

   %LET projSearch=more;
   %DO %WHILE ("&projSearch"="more");

      Data &ProjMeta;
      Set &ProjMeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath ;

         Length memname parentName Name $ 256;
         Length parentPath parentLocation $ &_EM_PATHLEN;
         Length mempath $ &_EM_PATHLEN;
         Length fext $ 8; /* file name extension */
         retain openDir 0;

         /* for each unprocessed dir in the data set */
         /* if done skip to next  dir */
         if (status > 0) or not(Type in ("dir","wsdir","root"))then do;
            Output;
            /* if no unprocessed dirs set done flag */
            if (lastobs and  not openDir) then
               call symput('projSearch','done');
         end;
         else do;

            /* process each open dir  */
            /* set relative path */
            root = SYMGET("RootName");
            rlen = LengthN("&RootPath");
            rbuf=substr(Path,rlen+2);
            RelPath = cats(root,"&_dsep",rbuf);

            /* save parent attributes */
            parentName = Name;
            parentPath = Path;
            parentType = Type;
            parentAction = Action;
            parentStatus = 1;
            ParentLocation = Location;
            fcnt = 0;

            if ("&_EM_TRACE" = "ON") then
               put RelPath;

            /* open the parent dir and process it's members */
            rc=filename("emdir", parentPath);
            did=dopen("emdir");
            if did = 0 then do;
               msg=sysmsg();
               put msg;
               goto errexit;
            end;
            memcount=dnum(did);
            action=0;

            i= 1;
            do while (i<= memcount);
               memname=dread(did,i);
               /* save location */
               location = parentPath;
               /* save name no extent ion */
               Name = scan(memname,1,'.');

               /* build member path */
               mempath = cats(parentPath,"&_dsep");
               mempath = cats(mempath, memname);

               rc = filename("memref", mempath);
               if (rc ne 0) then do;
                  emsg=sysmsg();
                  put emsg=;
                  goto errexit;
               end;

               if (not fexist("memref")) then do;
                  Error "ERROR: Listed file system directory member not found.";
                  goto errexit;
               end;

               /* try to open member as directory */
               mdid=dopen("memref");
               /* if a directory opened */
               if (mdid > 0) then do;
                  type = "dir";
                  path = mempath;
                  status= 0;
                  action = 0;
                  Output; /* output sub dir info */

                  openDir = 1; /* flag as unprocessed dir */

                  /* Close the sub dir */
                  rc=dclose(mdid);
                  /* clear the fileref */
                  rc = filename("memref");
               end;
               else do; /* non directory members must be files */

                  /* get file name extension */
                  fext = scan(memname, -1);
                  Fcount = 1;
                  action = 1;
                  path = mempath;

                  /* if SAS data Set */
                  if (indexw(fext, "sas7bdat") = 1)
                  then do;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "dfile";
                     status= 1;
                     Output;
                  end;
                  /* if SAS Catalog */
                  else if (indexw(fext, "sas7bcat") = 1)
                  then do;
                     parentAction = 1;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "cfile";
                     status= 1;
                     Output;
                  end;
                  /* if SAS data view */
                  else if (indexw(fext, "sas7bvew") = 1)then do;
                     parentAction = 1;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "view";
                     status= 1;
                     Output;
                  end;
                  /* if binary transport object */
                  else if (indexw(fext, "sto") = 1)then do;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "sto";
                     status= 2;
                     Output;
                  end;
                  /* if transport source */
                  else if (indexw(fext, "stc") = 1)then do;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "stc";
                     status= 2;
                     Output;
                  end;
                  /* if text file */
                  else if ((indexw(fext, "emp") = 1) or
                        (indexw(fext, "java") = 1) or
                        (indexw(fext, "c")   = 1) or
                        (indexw(fext, "txt") = 1) or
                        (indexw(fext, "st" ) = 1) or
                        (indexw(fext, "log") = 1) or
                        (indexw(fext, "out") = 1) or
                        (indexw(fext, "xml") = 1) or
                        (indexw(fext, "sas") = 1))
                  then do;
                     parentAction = 1;
                     parentStatus = 1;
                     fcnt = fcnt +1;
                     type = "tfile";
                     status= 2;
                     Output;
                  end;

                  /* no need to close member open failed */
                  /* clear the fileref */
                  rc = filename("memref");

               end; /* end file processing */

               i+1; /* increment to try next member */
            end;/* end do members */

            /* close the parent dir */
            rc= dclose(did);

            /* save the parent path */
            Name = parentName;
            Path = parentpath;
            Type = parentType;
            Action = parentAction;
            Status = parentStatus;
            Location = parentLocation;
            Fcount = fcnt;
            Output;

         end; /* each parent loop */

         goto normexit;
         errexit:

            if (did ne 0) then
               rc=dclose(did);
            call symput('projSearch','done');
            call symput('SYSCC','1012');

         normexit:

      Run;

      %IF &SYSERR ^= 0 %then %ABORT CANCEL;
   %END; /* end projSearch */

   /* set workspace dirs type */
   Data &ProjMeta;
   Set &ProjMeta;
      Keep Type Path Status Action Fcount Location Name RelPath;
      Length dname $ 32;
      Length rbuf $ &_EM_PATHLEN;

      if (Type = "dir") then do;
          /* any dir in workspaces is emws */
          rbuf=reverse(trim(location));
          dname = scan(rbuf,1,"&_dsep");
          dname = strip(Reverse(dname));
          if (dname = 'Workspaces') then Type = 'wsdir';
      end;

      /* set relative path */
      root = SYMGET("RootName");
      rlen = LengthN("&RootPath");
      rbuf=substr(Path,rlen+2);
      RelPath = cats(root,"&_dsep",rbuf);


   Run;
   %IF &SYSERR ^= 0 %then %ABORT CANCEL;

%Mend EM_MigrateProject_GetFileInfo;

/*******************************************************************
 * EM_MigrateProject_DataMap - discovers the libnames and data sets required
 *  to restore or run the target diagrams.
 * ProjMeta - name of work data set that contains the project info.
 * Outdata - data set to contain libnames and data set names.
 ********************************************************************/
%Macro EM_MigrateProject_DataMap(ProjMeta=, Outdata=);
    %LET SYSCC = 0;

   /* clear any old LibData */
    %IF %sysfunc(exist(&Outdata)) %THEN %DO;
       Proc Delete Data=&Outdata; Run;
    %END;

   /* for each diagram (wsdir type) publish name and location */
   %LET metasearch=more;
   %DO %WHILE ("&metasearch"="more");
      %LET WSPATH=;
      %LET WSNAME=;
      %LET metasearch= done;

      Data &ProjMeta;
      Set &ProjMeta end=lastobs;
         KEEP Type Path Status Action Fcount Location Name RelPath;
         Retain active 0;

         /* for each wsdir not already processed */
         if (Not active) and (Type = "wsdir") and (Status < 2) then do;
            call symput('WSPATH',strip(Path));
            call symput('WSNAME',strip(Name));
            Status = 2;
            active = 1;
            call symput('metasearch','more');
         end;
      Run;

      %IF &SYSERR ^= 0 %THEN %DO;
         %PUT ERROR: SYSERR = &SYSERR;
         %ABORT CANCEL;
      %END;

      /* if a diagram location is found */
      %IF (%LENGTH(&WSPATH)) %THEN %DO;
         /* get diagram node order to find root nodes */
         %EM_MigrateProject_WSnodeOrder( &WSPATH, _EMWS_NodeOrder);

         /* if the diagram is empty nothing to process */
         %IF %sysfunc(exist(_EMWS_NodeOrder)) %THEN %DO;

            /* set libname for diagram */
            Libname &WSNAME "&WSPATH";

            %IF &SYSERR ^= 0 %THEN %DO;
               %PUT ERROR: SYSERR = &SYSERR;
               %ABORT CANCEL;
            %END;

            /* make root node list */
            Data _nodelist (Keep = emwsid nodeid status);
            Set _EMWS_NodeOrder;
               if rootnode then do;
                  emwsid = SYMGET("WSNAME");
                  nodeid = nodename;
                  status = 0;
                  output;
               end;
            Run;

            %IF &SYSERR ^= 0 %THEN %DO;
               %PUT ERROR: SYSERR = &SYSERR;
               %ABORT CANCEL;
            %END;

            %LET nodesdone = 0;
            %DO %UNTIL (&nodesdone);
               %LET WSID =;
               %LET NODE =;
               /* get next node from nodelist */
               Data _nodelist (Keep = emwsid nodeid status);
               Set _nodelist end=lastobs;
                  Retain found 0;

                  /* done when last obs processed */
                  If (lastobs) and (status > 0) then do;
                     call symput('nodesdone','1');
                  end;

                  if (status =  0) and (found = 0)then do;
                     status = 1;
                     found = 1;
                     call symput('WSID',strip(emwsid));
                     call symput('NODE',strip(nodeid));
                  end;
               Run;

               %IF &SYSERR ^= 0 %THEN %DO;
                  %PUT ERROR: SYSERR = &SYSERR;
                  %ABORT CANCEL;
               %END;
               /* get info for each diagram */
               %IF (%LENGTH(&WSID)) %THEN %DO;
                  %EM_MigrateProject_LibData(emwsid=&WSID, nodeid=&NODE, output=&outdata);
               %END;
               %IF &SYSCC ^= 0 %THEN %DO;
                  %EM_MigrateProject_MigrateLog(WMSG= Project data map preperation failed);
                  %GOTO ENDDATAMAP;
               %END;
            %END; /* nodesdone */

            Proc Delete Data=WORK._nodelist; Run;
         %END;
      %END; /* WSPATH */
   %END; /* metasearch */

   %IF %sysfunc(exist(PRJ.libdata)) %THEN %DO;

      /* log fileimport file names */
      Data _NULL_;
      Set PRJ.libdata end=lastobs;
         Retain start 1;
         Length outbuf $  &_EM_PATHLEN;
         File logfile MOD;
         if (IFileName ne '') then do;

            if (start) then do;
               put ;
               outbuf = CAT(" Files accessed via File Import required to run this project include: ");
               put outbuf;
               put;
               outbuf = CAT(" Diagram                          ", "NodeID                           ", "Imported File Path                                 ");
               put outbuf;
               put"---------------------------------------------------------------------------------------------------------------------------";
               start = 0;
            end;

            outbuf = CAT(" ", EMWSID,' ',  NODEID,' ',strip(IFileName));
            put outbuf;

          end;
          if ((lastobs) and (start=0)) then do;
             put"---------------------------------------------------------------------------------------------------------------------------";
             put;
          end;
          File LOG;
      Run;

      /* log the required libnames and data set info */
      Data _NULL_;
      Set PRJ.libdata end=lastobs;
      retain start 1;
      Length outbuf $ 256;
         File logfile MOD;
         if (library ne '') then do;

            if (start) then do;
               put;
               outbuf = CAT(" Libnames and data sets required to run project include: ");
               put outbuf;
               put;
               outbuf = CAT(" ","Diagram                          ", "NodeID                           ", "Libname ", " Data set                        " );
               put outbuf;
               put"---------------------------------------------------------------------------------------------------------------------------";
               start = 0;
            end;

            outbuf = CAT(' ',EMWSID,' ',  NODEID,' ', library,' ', dsname);
            put outbuf;
         end;

         if ((lastobs) and (start = 0)) then do;
            put"---------------------------------------------------------------------------------------------------------------------------";
            put;
         end;
         File LOG;
      Run;
   %END;
   %PUT NOTE: EM_MigrateProject_DataMap completed.;
   %ENDDATAMAP:
%Mend EM_MigrateProject_DataMap;

/*******************************************************************
 * EM_MigrateProject_LoadEMProps - Loads EM's model properties reader used
 * in EM_MigrateProject_LibData.
 ********************************************************************/
%Macro EM_MigrateProject_LoadEMProps;
   /* Load EM macro from catalog for EM_MigrateProject_LibData */
   Filename _emrpm catalog 'sashelp.emrpm.em_modelprops.source';
   %IF %SYSFUNC(fileref(_emrpm))= 0  %THEN %DO;
      %INC _emrpm;
      Filename _emrpm;
      %LET _EM_Load_em_modelprops = 1;
   %END;
   %ELSE %LET _EM_Load_em_modelprops = 0;
%Mend EM_MigrateProject_LoadEMProps;

/*******************************************************************
 * EM_MigrateProject_LibData - reads the diagrams properties to get the required
 * libref and data set name for the root node specified.
 ********************************************************************/
%Macro EM_MigrateProject_LibData(emwsid=, nodeid=, output=);

   /* save current options */
   Proc OPTSave OUT=WORK._LibdataOpts; Run;
   Options NOSOURCE;

   /* get properties */
   %em_modelprops(dgmid=&emwsid, modelid=&nodeid, output=%nrbquote(WORK.properties));
   %IF (&SYSCC ^= 0) %THEN %DO;
      %EM_MigrateProject_MigrateLog(WMSG= Unable to load macro for project data map preperation);
      %RETURN;
   %END;

   %LET IDSFlag = 0;
   Data _null_;
      Set WORK.properties;
      where SOURCE='COMMON' and (NAME in ('COMPONENT', 'CLASS'));
      if (upcase(NAME)='COMPONENT' and
          (upcase(value) = 'DATASOURCE' or
           upcase(value) = 'FILEIMPORT')) then
         call symput('IDSFlag', '1');
      else if (upcase(NAME)='CLASS' and upcase(value) = 'SASHELP.EMSAMP.IDS')  then
         call symput('IDSFlag', '1');

   Run;
   %IF &IDSFlag %THEN %DO;
      Data _temp;
         Length EMWSID NODEID $32 library $8 dsname $32;
         Length IFileName $ &_EM_PATHLEN;
         Retain EMWSID "&emwsid" nodeid "&nodeid" library '' dsname '' IFileName '' newFlag 0;
      Set WORK.properties end=eof;
         keep emwsid nodeid library dsname IFileName;

         NAME = upcase(NAME);

         Where SOURCE='PROPERTIES' ;

            if NAME = 'LIBRARY' then library=value;
            else
            if NAME = 'TABLE' then dsname=value;
            else
            if NAME= 'IFILENAME' then IFileName=value;
            else
            if NAME= 'DATASELECTION' and upcase(value)='USERTABLE' then newFlag=1;

         if newFlag then do;
            library = scan(value, 1, '.');
            dsname  = scan(value, 2, '.');
         end;

         if eof then do;
            if ((IFileName ne '') or (library ne '' and dsname ne '')) then output;
         end;
       Run;

       /* add temp to libdata output */
       Proc Append base=&output data=_temp force;
       Run;

       Proc Delete data=_temp; Run;

   %END;

   Proc Delete data=WORK.properties; Run;

   Proc Sort Data=&output Out=&output NODUPRECS;
         BY DESENDING EMWSID;
   Run;

   /* reset any SAS options that may have changed */
   Proc OPTLoad DATA=_LibdataOpts; Run;
   %IF %SYSFUNC(exist(WORK._LibdataOpts)) %THEN %DO;
       Proc Delete Data=WORK._LibdataOpts; Run;
   %END;
%Mend EM_MigrateProject_LibData;

/*******************************************************************
 * EM_MigrateProject_ReMakeViewCode - moves the raw view code file 
 *  to the final view code file. in the process it modifies the code
 * if needed and deletes the raw code file if no error was detected.
 * Parm1 = full path for raw view code file (will be deleted)
 * Parm2 = full path for final view code file 
 ********************************************************************/
%Macro EM_MigrateProject_ReMakeViewCode(RawVCPath, NewVCPath);
  %LET SYSCC = 0;

  DATA _NULL_;

   Length msg cline modline modline1  modline2 $256;
   Length word $ 16;
   
   /* Open input file */ 
   rc = filename('Org_f' );
   rc = 0;
   rc = filename('Org_f', "&RawVCPath");
   if (not rc = 0) then do;
      put "FILENAME for raw view file failed";
      put "Raw view file = &RawVCPath";
      msg = substr( sysmsg(), 6);
      put  "WARNING" msg; 
      msg = sysmsg();
      put msg;
      call symput('SYSCC','4');
      goto close;
   end;

   fid_org = fopen('Org_f', 'I');
   if (not fid_org > 0) then do;
      put "WARNING: FOPEN for raw view file failed.";
      put "Raw view file = &RawVCPath";
      msg = substr( sysmsg(), 6);
      put  "WARNING" msg;     
      call symput('SYSCC','4');
      goto close;
   end;

   /* Open output file */ 
   rc = filename('New_f');
   rc = 0;
   rc = filename('New_f', "&NewVCPath");
   if (not rc = 0) then do;
      put "FILENAME for view code file failed";
      put "View code file = &NewVCPath";
      msg = substr( sysmsg(), 6);
      put  "WARNING" msg; 
      msg = sysmsg();
      put msg;
      call symput('SYSCC','4');
      goto close;
   end;

   fid_New = fopen('New_f', 'O');
   if (not fid_New > 0) then do;
      put "WARNING: FOPEN for view code file failed.";
      put "View code file = &NewVCPath";
      msg = substr( sysmsg(), 6);
      put  "WARNING" msg;      
      call symput('SYSCC','4');
      goto close;
   end;
 
   /* while input */
   do while(fread(fid_org)=0);

      rc = fget(fid_org, cline, 256);

      /* Check for double else */

      pos= find(cline, 'else','i',1);
   
      /* if it has one ...*/
      if pos then do;
         /* save everything up to it */
         if (pos > 1) then modline1 = substr(cline, 1,pos-1);

         /* check next word for anonter one */
         call scan( substr(cline,pos+4), 1, spos, len);

         /* if any words left */
         if spos > 0 then do;
            /* Get next word */
            word = substr(cline, pos+4+spos-1, 4);

            if (word = "else") or (word = "ELSE") then do;
               /* omit that word and copy everthing after it */
               modline2 = substr(cline, pos+spos+3);

                /* cat everything before the second else and everthing after */
                modline = cat(TRIM(modline1), TRIM(modline2));
                
                /* save works so far */
                cline = modline;
            end;
         end;
      end;

      /* Check for double otherwise */
      pos= find(cline, 'otherwise','i',1);
 
      if pos then do;
         if pos >1 then modline1 = substr(cline, 1,pos-1);
 
         call scan( substr(cline,pos+9), 1, spos, len);

         if spos > 0 then do;
            word = substr(cline, pos+9+spos-1, 9);

            if (word = "otherwise") or (word = "OTHERWISE") then do;

               modline2 = substr(cline, pos+spos+7);

               modline = cat(TRIM(modline1),  TRIM(modline2));
               
               /* save changes */
               cline = modline;               
            end;
         end;
      end; 

      /* check for double colon */
      pos= find(cline, ':','i',1);

      if pos then do;
         if pos >1 then modline1 = substr(cline, 1,pos-1);

         call scan( substr(cline,pos+1), 1, spos, len);

         if spos > 0 then do;
            word = substr(cline, pos-1+spos+1, 1);
 
            if (word = ":") then do;
               modline2 = substr(cline, pos+spos);

               modline = cat(TRIM(modline1),  TRIM(modline2));
               /* save changes */
               cline = modline;               
            end;
         end;
      end;

      /* load output buffer */
      rc = fput(fid_new, cline);
      if (not rc = 0) then do;
         put "WARNING: FPUT for view code file failed.";
         msg = substr( sysmsg(), 6);
         put  "WARNING" msg;         
         call symput('SYSCC','4');
         goto close;
      end;
      
      /* write buffer out */
      rc = fwrite(fid_New);
      if (not rc = 0) then do;
         put "WARNING: FWRITE for view code file failed";
         msg = substr( sysmsg(), 6);
         put  "WARNING" msg;
         call symput('SYSCC','4');
         goto close;
      end;      
   end; /* end read */   

   close:;
   /* close, delete raw input file and clear */
   err = symgetn('SYSCC');
      
   rc = fclose(fid_org);
   rc = fclose(fid_new);
   
   /* only deletes if everything worked */
   if (err = 0) then do;
       if (fexist('New_f') and fexist('Org_f'))  then 
            rc = fdelete('Org_f');
   end;
 
   rc = filename('Org_f');
   rc = filename('New_f');
    
Run; 
%Mend EM_MigrateProject_ReMakeViewCode; 


/*******************************************************************
 * EM_MigrateProject_PrepViews - Extracts code from all data views to 
 * .STC files
 * ProjMeta - name of work data set to contain the project info.
 ********************************************************************/
%Macro EM_MigrateProject_PrepViews(ProjMeta=_EMProj);
   %LET VPrepCC = 0;
   %LET SYSCC = 0;
   /* process until no more actions pending (action=1) */
   %LET loopstate=more;
   %DO %WHILE ("&loopstate"="more");
      %LET View_Targ=;
      %LET View_Name=;
      %LET View_Rel=;

      Data &ProjMeta;
      Set &ProjMeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath;
         Retain acts 0;   /* stop searching if an action target found */

         if ((Type = "view") and ( Action = 1) and (acts = 0)) then do;
            /* save strings needed to run views */
            call symput('View_Targ',strip(Location));
            call symput('View_Name',strip(Name));
            call symput('View_Rel',strip(RelPath));

            action = 0;
            acts = acts+1;
         end;

         /* if no actions set done flag */
         if (lastobs and not acts) then do;
            call symput('loopstate','done');
         end;
      Run;
                               /* save current options              */
      Proc OPTSave OUT=WORK._sasopts; run;

      /* prepare SAS data views */
      %IF (%LENGTH(&View_Targ)) %THEN %DO;
         %IF ("&_EM_TRACE" = "ON") %THEN
            %PUT Preparing SAS view &View_Rel.;

         /* clear any old view code file */
         %IF %sysfunc(fileexist("&View_Targ&_dsep&View_Name..stc")) %THEN
            %EM_MigrateProject_DeleteFile(&View_Targ&_dsep&View_Name..stc);
            
         /* clear any old raw view file */
         %IF %sysfunc(fileexist("&View_Targ&_dsep&View_Name..stx")) %THEN
            %EM_MigrateProject_DeleteFile(&View_Targ&_dsep&View_Name..stx);
            
         /* get raw view source code and save it */
         Libname PRJ "&View_Targ";

         /* set options to prevent extraneous output */
         Options NONOTES NOSOURCE NOMPRINT NOMLOGIC;
         %LET SYSCC = 0;

         Proc Printto LOG="&View_Targ&_dsep&View_Name..stx";
         Run;

         Data View=PRJ.&View_Name;
            DESCRIBE;
         Run;

         %LET VRC = &SYSCC;
         
         /* turn log output on */
         Proc Printto;
         Run;

         %IF &VRC ^= 0 %THEN %DO;
            %PUT WARNING: &SYSERRORTEXT..;
            %EM_MigrateProject_MigrateLog(WMSG= View preparation failed for &View_Name);
            %EM_MigrateProject_DeleteFile(&View_Targ&_dsep&View_Name..stx);
            %PUT;
            %LET VPrepCC = %EVAL(&VPrepCC +1); /* Most views not required */
         %END;

         /* set options back */
         Proc OPTLoad DATA=WORK._sasopts; Run;

         %IF %sysfunc(exist(WORK._sasopts)) %THEN %DO;
            Proc Delete Data=WORK._sasopts;; Run;;
         %END;
         
         %IF &VRC = 0 %THEN %DO; 
            /* convert raw view file (.stx) to code file (.stc)*/
            %EM_MigrateProject_ReMakeViewCode(&View_Targ&_dsep&View_Name..stx, 
                                               &View_Targ&_dsep&View_Name..stc);                                  
         %END;
         
         %IF &SYSERR ^= 0 %then %ABORT CANCEL;
      %END; /* end view_targ */
   %END; /* end prep processing loop */

   %LET SYSCC = &VPrepCC;
%Mend EM_MigrateProject_PrepViews;


/*******************************************************************
 * EM_MigrateProject_PrepTxt - creates new _trantxt catalog entries for all text
 *   files
 * ProjMeta - name of work data set to contain the project info.
 ********************************************************************/
%Macro EM_MigrateProject_PrepTxt(ProjMeta=_EMProj);
   /* process until no more tfiles with action pending (action=1) */
   %LET SYSCC = 0;
   %LET ECNT = 1;
   %LET txtSearch=more;

   %DO %WHILE ("&txtSearch"="more");
      %LET T_Path =;
      %LET T_Loc=;
      %LET T_Cat=;
      %LET T_Fname=;
      %LET EntryName = txt&ECNT;

      Data &ProjMeta;
      Set &ProjMeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath;
         Length strbuf Fname $ 256;
         Retain acts 0;   /* stop searching if an action target found */

         if (((Type = "tfile") or (Type = "stc"))and
              (action = 1) and (acts = 0) and
              (strip(Name) ^= 'EMProjPREPARELog')) then do;
            call symput('T_Path',strip(Path));
            call symput('T_Loc',strip(Location));
            call symput('T_Rel',strip(RelPath));
            /* build catalog reference string */
            strbuf = CAT("PRJ._trantxt.","&EntryName",".source");

             call symput('T_Cat',strip(strbuf));

            /* get file name with extention */
            fname = scan(Path,-1,"&_dsep");

            call symput('T_FName',strip(fname));

            action = 2;
            acts = acts+1;
         end;

         /* if no actions set done flag */
         if (lastobs and not acts) then do;
            call symput('txtSearch','done');
         end;
      Run;

      /* convert text to cat entry */
      %IF (%LENGTH(&T_Path)) %THEN %DO;
         %IF ("&_EM_TRACE" = "ON") %THEN
            %PUT Preparing text file, &T_Rel..;

         Libname PRJ "&T_Loc";
         Filename tcat CATALOG "&T_cat" DESC="&T_Fname";

         Data  _NULL_;
            File tcat ;

            Length text $ &_EM_PATHLEN;
            text = ' ';

            /* set text file filename */
            rc = Filename("txt","&T_Path");
            if rc ne 0 then do;
               put "ERROR Filename failed";
               msg = sysmsg();
               ERROR msg=;
               call symput('SYSCC','8');
               STOP;
            end;

           /* establish text file LRECL */
           fid = fopen("txt",'i',,'d');
           if (fid > 0) then do;
              reclen = finfo(fid,"LRECL");
              rc = fclose(fid);
              lrecl = input(reclen,Best.);
              /* check for lrecl to small */
              if lrecl <1024 then lrecl = 1024;
           end;
          else do;
             put "ERROR: Open failed for file, &T_Path.";
             emsg=sysmsg();
             put "ERROR: " emsg;
             call symput('SYSCC','8');
             STOP;
          end;

          /* must Re-open with LRECL specified */
          fid = fopen("txt",'i',lrecl,'d');
          if fid > 0 then do;

             do while(fread(fid) = 0);
                rc=fget(fid,text,256);
                put text;
             end;

             rc = fclose(fid);
          end;
          else do;
             put "ERROR:  Open failed for file &T_Path";
             msg = sysmsg();
             ERROR msg=;
             call symput('SYSCC','9');
             STOP;
          end;

        Run;

         %IF (&SYSERR ^= 0) %THEN %DO;
            %PUT ERROR: Preparing failed for text file &T_Path;
            %ABORT CANCEL;
         %END;

         Libname PRJ clear;

         /* increment entryname for next file */
         %LET ECNT = %EVAL(&ECNT +1);
         %LET EntryName = txt&ECNT;

      %END;/* end if t_Path */
   %END;/* end prepare text files */
 %Term:;
%Mend EM_MigrateProject_PrepTxt;

/*******************************************************************
 * EM_MigrateProject_PrepCat - cports all catalogs
 * ProjMeta - name of work data set that contains the project info.
 ********************************************************************/
%Macro EM_MigrateProject_PrepCat(ProjMeta=_EMProj);
   /* process until no more actions pending (action=1) */
   %LET loopstate=more;
   %DO %WHILE ("&loopstate"="more");
      %LET Port_Targ =;

      Data &ProjMeta;
      Set &ProjMeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath;
         Retain acts 0;   /* stop searching if no action target found */

         if (((Type = "dir") or (Type = "root") or (Type = "wsdir")) and
              ( action = 1) and (acts = 0)) then do;
            call symput('Port_Targ',strip(Path));
            call symput('Port_Rel',strip(RelPath));
            action = 0;
            acts = acts+1;
         end;

         /* if no actions set done flag */
         if (lastobs and not acts) then do;
                  call symput('loopstate','done');
         end;
      Run;

      /* prepare catalogs and data sets */
      %IF (%LENGTH(&Port_Targ)) %THEN %DO;

         Libname PRJ "&Port_Targ";
         %IF ("&_EM_TRACE" = "ON") %THEN
            %PUT CPorting &Port_Rel;

         Proc Cport LIB= PRJ DATECOPY
            MEMTYPE=CATALOG
            FILE="&Port_Targ&_dsep.lib.sto";
         Run;

         %LET CportRC = &SYSINFO;

         %IF %EVAL(&CportRC ^= 0) %THEN %DO;
            %LET SYSCC = &CportRC;
            %EM_MigrateProject_MigrateLog( WMSG= Cporting issues reported for &Port_Targ);
            %EM_MigrateProject_MigrateLog( WMSG=%SYSFUNC(sysmsg()) );
         %END;
         %IF &SYSERR ^= 0 %then %ABORT CANCEL;

         Libname PRJ clear;

      %END;/* end prepare catalogs and data sets */
   %END; /* end prep processing loop */
   %DatCatEXIT:
 %Mend EM_MigrateProject_PrepCat;

/*******************************************************************
 * EM_MigrateProject_CleanProj - Finds and deletes the migration files in the
 * project.
 *
 * ProjMeta - name of work data set that contains the project info.
 * %IF (&Action=RESTORE) %THEN %DO;
 ********************************************************************/
%Macro EM_MigrateProject_CleanProj(Projmeta=_EMProj, Action= );
   %PUT ;
   %PUT Cleaning project ...;
   /* select files to be deleted */
   %IF (&Action=RESTORE) %THEN %DO;
      Data _migrateTMP;
      Set &Projmeta;
         Length fext $ 32;

         if (Name = 'EMProjRESTORELog') then goto next;

         if (Type = "sto") or (Type = "stc") then do;
            status=0;
            Output;
         end;
         else if (Type = "cfile") then do;
                               /* get file name extension */
            fext = scan(Path, -1);
                               /* if _trantxt.sas7bcat    */
            if (indexw(fext, "sas7bcat") = 1) and
                (indexw(Name, "_trantxt") = 1) then do;
               status=0;
               Output;
            end;
         end;
         next:;
      Run;
   %END;
   %ELSE %DO; /* for ACTION = PREPARE  */
      Data _migrateTMP;
      Set &Projmeta;
         if (Name = 'EMProjPREPARELog') then goto next;
         if (Type = "dfile") then do;
            status=1;
            Output;
         end;
         if (Type = "cfile") or
            (Type = "view") or
            (Type = "stc") or
            (Type = "tfile")
            then do;
            status=0;
            Output;
         end;
         next:;
      Run;
   %END;

   %IF &SYSERR ^= 0 %then %ABORT CANCEL;

   %LET ClrStatus=more;

      %DO %WHILE ("&ClrStatus"="more");
         %LET Clr_Path=;
         Data _migrateTMP;
         Set _migrateTMP end=lastobs;
            Retain acts 0;   /* stop searching if an action target found */
            DROP acts;
            /* find and delete all transported files */
            if (acts = 0) and (Status = 0) then do;

               call symput('Clr_Path',strip(Path));
               Status = 1;
               acts = 1;
            end;

            /* if no actions set done flag */
            if (lastobs and not acts) then do;
               call symput('ClrStatus','done');
            end;
         Run;

         %IF (%LENGTH(&Clr_Path)) %THEN %DO;
               %EM_MigrateProject_DeleteFile(&Clr_Path);
         %END;

      %END; /* ClrStatus */

%Mend EM_MigrateProject_CleanProj;

/*******************************************************************
 * EM_MigrateProject_RestoreCats - Finds each lib.sto file and extracts the
 * SAS files (catalogs)
 * ProjMeta - name of work data set that contains the project info.
 ********************************************************************/
%Macro EM_MigrateProject_RestoreCats(Projmeta=_EMProj);

   %LET sfileStatus=more;
   %LET portcnt=0;
   %DO %WHILE ("&sfileStatus"="more");
      %LET Port_Targ =;
      %LET View_Targ=;
      %LET View_Name=;

      Data &Projmeta;
      Set &Projmeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath;
         Retain acts 0;   /* stop searching if an action target found */

         /* find and process all transport objects (lib.sto) */
         if ((Type = "sto") and ( action = 1) and (acts = 0)) then do;
            call symput('Port_Targ',strip(location));
            call symput('Port_Rel',strip(RelPath));
            action = 0; /* prevent reprocessing */
            acts = acts+1;
         end;

         /* if no actions set done flag */
         if (lastobs and not acts) then do;
               call symput('sfileStatus','done');
         end;
      Run;

      %IF (%LENGTH(&Port_Targ)) %THEN %DO;
         %LET portcnt = %EVAL(&portcnt + 1);
         /* restore catalog and data sets */
         %IF ("&_EM_TRACE" = "ON") %THEN
            %PUT Restoring SAS files from &Port_Rel;

         Libname PRJ "&Port_Targ";

         Proc Cimport NEW
            INFILE="&Port_Targ&_dsep.lib.sto"
            LIB= PRJ;
         RUN;
         %IF &SYSERR ^= 0 %then %ABORT CANCEL;

      %END; /* if Port_Targ */
   %END; /* end restore catalogs and data sets */

   %IF (%EVAL(&portcnt = 0)) %THEN %DO;
      %EM_MigrateProject_MigrateLog(EMSG= No prepared files found in project);
      %LET SYSCC = 8;
   %END;
%Mend EM_MigrateProject_RestoreCats;

/*******************************************************************
 * EM_MigrateProject_CheckDataMap - checks for the existance of the libnames and
 * data set in the EM_MigrateProject_DataMap output data set.
 * DataMap - data set containing required libnames and data set names.
 ********************************************************************/
%Macro EM_MigrateProject_CheckDataMap(DataMap=);
   %IF ("&_EM_TRACE" = "ON") %THEN %DO;
      %PUT ;
      %PUT Checking required project librefs ...;
   %END;
   /* check for data map */
   %IF not (%SYSFUNC(exist(&DataMap))) %THEN %DO;
      %EM_MigrateProject_MigrateLog(WMSG= Data map for project not found);
      %LET SYSCC = 8;
      %RETURN;
   %END;

   %LET SYSCC = 0;

   Data _NULL_;
   Set &DataMap;
      Length msgbuf $ 256;
      Length ref  $ 100;
      msgbuf = ' ';

      if (library ^= '') then do;
         ref=CATX('.',library,dsname);

         rc = libref(library);
         if (rc = 0) then do;
            if (EXIST(ref)) then do;
               put "Found required data source - " ref;
               File logfile MOD;
               put "Found required data source - " ref;
               File LOG;
            end;
            else do;
               msgbuf=sysmsg();
               put msgbuf;
               File logfile MOD;
               put msgbuf;
               File LOG;
               call symput('SYSCC','4');
               msgbuf = CATX(' ',"WARNING: A project libname.membername,", ref, "is not found.");
               put msgbuf;
               File logfile MOD;
               put msgbuf;
               File LOG;
            end;
         end;
         else do;
            call symput('SYSCC','4');
            msgbuf = CATX(' ',"WARNING: A project libname for,", ref,"is not found.");
            put msgbuf;
            File logfile MOD;
               put msgbuf;
            File LOG;
         end;
      end;
      else if (IFileName ^= '') then do;
         /* check for path existance */
         if (fileexist(IFileName)) then do;
            put "Found required data source - " IFileName;
            File logfile MOD;
               put "Found required data source - " IFileName;
            File LOG;
         end;
         else do;
            msgbuf=sysmsg();
            put msgbuf;
            File logfile MOD;
               put msgbuf;
            File LOG;
            msgbuf = CATX(' ',"WARNING: Imported project input data file is not found.");
            put msgbuf;
            File logfile MOD;
               put msgbuf;
            File LOG;
            call symput('SYSCC','4');
         end;
      end;
   Run;
   %IF (&SYSERR ^= 0) or (&SYSCC ^= 0) %THEN %DO;
      %EM_MigrateProject_MigrateLog(WMSG= Unable to verify all libnames and data sources for project);
   %END;
%Mend EM_MigrateProject_CheckDataMap;

/*******************************************************************
 * EM_MigrateProject_RestoreData - Finds each dataset and converts it to the
 * local format
 * ProjMeta - name of work data set that contains the project info.
 ********************************************************************/
%Macro EM_MigrateProject_RestoreData(Projmeta=_EMProj);

   %LET dfileStatus=more;
   %LET portcnt=0;
   %DO %WHILE ("&dfileStatus"="more");
      %LET Port_Targ =;
      %LET View_Targ=;
      %LET View_Name=;

      Data &Projmeta;
      Set &Projmeta end=lastobs;
         Keep Type Path Status Action Fcount Location Name RelPath;
         Retain acts 0;   /* stop searching if an action target found */

         /* find and process all transport objects (lib.sto) */
         if ((Type = "dfile") and ( action = 1) and (acts = 0)) then do;
            call symput('Port_Name',strip(Name));
            call symput('Port_Targ',strip(Location));
            call symput('Port_Rel',strip(RelPath));
            action = 0; /* prevent reprocessing */
            acts = acts+1;
         end;

         /* if no actions set done flag */
         if (lastobs and not acts) then do;
               call symput('dfileStatus','done');
         end;
      Run;

      %IF (%LENGTH(&Port_Targ)) %THEN %DO;
         %LET portcnt = %EVAL(&portcnt + 1);
         /* convert data sets */
         %IF ("&_EM_TRACE" = "ON") %THEN
            %PUT Restoring SAS data file &Port_Rel;

         Libname PRJ "&Port_Targ";

         /* convert to local format */
         Proc Copy In=PRJ Out=WORK NOCLONE DATECOPY;
            Select &Port_Name(memtype=DATA);
         Run;

         /* copy new local version back to project location */
         Proc Copy In=work  Out=PRJ MOVE DATECOPY;
          Select &Port_Name(memtype=DATA);
         Run;

         %IF &SYSERR ^= 0 %then %ABORT CANCEL;

      %END; /* if Port_Targ */
   %END; /* end restore catalogs and data sets */

   %IF (%EVAL(&portcnt = 0)) %THEN %DO;
      %EM_MigrateProject_MigrateLog(EMSG= No data files found in project);
      %LET SYSCC = 8;
   %END;
%Mend EM_MigrateProject_RestoreData;

/*******************************************************************
 * EM_MigrateProject_RestoreText - Finds each _trantxt catalog and extracts the
 *  each entry as a text file.
 * ProjMeta - name of work data set that contains the project info.
 ********************************************************************/
%Macro EM_MigrateProject_RestoreText(Projmeta=_EMProj);
   /* make list of all _trantxt catalogs */
   Data WORK._txtcats;
   Set &ProjMeta end=Lastobs;
   Length fext $ 32;
   Retain cnt 0;
   Drop cnt;
   fext='';
   Keep Type Path Location Status Name RelPath;
      /* if  a sas catalog file  */
      if (Type = "cfile") then do;
                                /* get file name extension */
         fext = scan(Path, -1);
                               /* if _trantxt.sas7bcat */
         if (indexw(fext, "sas7bcat") = 1) and
            (indexw(Name, "_trantxt") = 1) then do;
            cnt = cnt + 1;
            Status = 1;
            Output;
         end; /* _trantxt cat */
      end; /* cfile */
      if Lastobs then
         call symput('TranTxtCnt',cnt);
   Run;

   %IF (%EVAL(&TranTxtCnt = 0)) %THEN %DO;
      %PUT ERROR: No prepared text found in project.;
      %LET SYSCC = 8;
      %LET txtSearch=done;
   %END;
   %ELSE %DO;
      %LET txtSearch=more;
   %END;

   %DO %WHILE ("&txtSearch"="more");
      %LET T_CatLoc =;

      Data WORK._txtcats ;
      Set WORK._txtcats end=lastobs;
         Keep Type Path Status Location Name;
         Retain active 0;
         /* if not sas file or already checked skip to next */
         if (Status > 1) or (active = 1) then do;
            Output;
         end;
         else do;   /* set catalog location */
            active = 1;
            Status = 2; /* set status checked */
            Output;
            call symput('T_CatLoc',strip(Location));
         end; /* set cat loc */

         /* if no unprocessed cats set done flag */
         if (lastobs and not active) then
            call symput('txtSearch','done');
      Run;

      %IF (&SYSERR ^= 0) %THEN %ABORT CANCEL;

      %IF (%LENGTH(&T_CatLoc)) %THEN %DO;
            %IF ("&_EM_TRACE" = "ON") %THEN %DO;
               %PUT;
               %PUT Restoring text in &T_CatLoc.;
            %END;

            Libname PRJ "&T_CatLoc";
            /* Get text catalog info */
            Proc Catalog Catalog=PRJ._trantxt;
               Contents OUT=WORK._catmeta;
            Run;

            /* Create entry names and matching file path */
            Data WORK._catmeta;
            Set WORK._catmeta;
             Length TxtPath $ &_EM_PATHLEN;
             Length CatEntry $ 83;
             Length lpath $ &_EM_PATHLEN;
             TxtPath = '';
             CatEntry = '';
             lpath ='';
             Keep Status CatEntry TxtPath;
             Status = 1;
               lpath =Pathname(LIBNAME,"L");
               TxtPath = CAT(Strip(lpath),"&_dsep",Strip(DESC));
               CatEntry=CAT(Strip(LIBNAME),".",Strip(MEMNAME),".",Strip(NAME),".",Strip(Type));
            Run;

            /* Process each cat entry */
            %LET tcatEntries=more;
            %DO %WHILE ("&tcatEntries"="more");
               %LET T_CatEnt =;
                Data WORK._catmeta;
                Set WORK._catmeta end=lastobs;
                   Keep Status CatEntry TxtPath;
                   Retain active 0;
                   if (status = 1) and (not active) then do;
                      call symput('T_CatEnt',Strip(CatEntry));
                      call symput('T_Path',Strip(TxtPath));
                      Status = 2;
                      active = 1;
                   end;

                   /* if no unprocessed entries set done flag */
                   if (lastobs and not active) then
                     call symput('tcatEntries','done');
                Run;
                %IF &SYSERR ^= 0 %then %ABORT CANCEL;

                %IF (%LENGTH(&T_CatEnt)) %THEN %DO;
                   %IF ("&_EM_TRACE" = "ON") %THEN
                      %PUT Restoring text from entry &T_CatEnt.;

                   Filename tcat CATALOG "&T_CatEnt";
                   Filename txt "&T_Path";

                   Data _NULL_;
                   Length txtbuf $ 256;
                     txtbuf='';

                     fid = fopen("tcat");
                     if fid > 0 then do;
                        File txt ;
                        do while(fread(fid) = 0);
                           rc=fget(fid,txtbuf,256);
                           put txtbuf;
                        end;
                        File LOG ;
                        rc = fclose(fid);
                     end;
                     else do;
                        /* project may still be all or partially usable */
                        put "WARNING: open failed for catalog entry, &T_CatEnt.";
                        msg = sysmsg();
                        put msg=;
                     end;
                   Run;
                   %IF &SYSERR ^= 0 %then %ABORT CANCEL;

                %END;

            %END; /* tcatEntries */

            %IF &SYSERR ^= 0 %then %ABORT CANCEL;

      %END; /* T_CatLoc */

      %IF (%sysfunc(libref(PRJ))) %THEN
         Libname PRJ CLEAR;

   %END; /* end txtSearch */

   %IF %sysfunc(exist(WORK._catmeta)) %THEN %DO;
     Proc Delete Data=WORK._catmeta; Run;
   %END;

   %IF %sysfunc(exist(WORK._txtcats)) %THEN %DO;
     Proc Delete Data=WORK._txtcats; Run;
   %END;
%Mend EM_MigrateProject_RestoreText;

/*******************************************************************
 * EM_MigrateProject_RestoreViews - Finds each .stc file in the project and
 *  submits the code to created the views. The view must be created
 * in the correct workspace with the correct libname and in the same
 * order as the nodes are executed in the diagram.
 *
 * ProjMeta - name of work data set that contains the project info.
 ********************************************************************/
%Macro EM_MigrateProject_RestoreViews(Projmeta=_EMProj);
      %LET RDVrc = 0;
      /* Find all the view files (.stc)*/
      Data WORK._EM_Views;
      Set &Projmeta end=Lastobs;
         Length rloc $ &_EM_PATHLEN;
         Length wsname $ 8;
         Length nodeName $ 32;
         Drop rloc;
         Retain cnt 0;
         Drop cnt;

         if type = "stc"  then do;
            /* get EM Workspace name from location */
            rloc=reverse(trim(location));
            wsname = scan(rloc,1,"&_dsep");
            wsname = strip(Reverse(wsname));

            /* get the node name from the view's name */
            nodeName= Upcase(scan(name,1,"_"));
           Output;
           cnt = cnt+1;
        end;

        if Lastobs then
           call symput('EMViewCnt',cnt);
      Run;

      %IF (%EVAL(&EMViewCnt = 0)) %THEN %DO;
          %EM_MigrateProject_MigrateLog(WMSG= No prepared data views found in project);
          %LET RDVrc = 4;
          %GOTO RDV_Exit;
      %END;

      %IF (&SYSERR ^= 0) %THEN %ABORT CANCEL;

      /* build each workspace node order */
      /* each WS node order info gets appended, clear old data */
      %IF %sysfunc(exist(WORK._EMWS_NodeOrder)) %THEN %DO;
         Proc Datasets LIB=WORK MEMTYPE=(data) NOLIST;
            Delete _EMWS_NodeOrder;
         Run;
         Quit;
      %END;

      %LET wsStatus=more;
      %DO %WHILE ("&wsStatus"="more");
         %LET EMWS_Path =;

         Data _EM_Views;
         Set _EM_Views end=lastobs;
            Drop acts;
            Retain acts 0;   /* stop searching if no action target found */

            if (Status < 3) and (not acts) then do;
               call symput('EMWS_loc',strip(location));
               call symput('EMWS_name',strip(wsname));
               Status = 3;
               acts = 1;
            end;

            /* if no actions set done flag */
            if (lastobs and not acts) then do;
                call symput('wsStatus','done');
            end;
         Run;

         /* if target WS location found, process it */
         %IF (%LENGTH(&EMWS_loc)) %THEN %DO;
            %EM_MigrateProject_WSnodeOrder(&EMWS_loc, _wsorder);
                               /* check for empty diagram */
            %IF %sysfunc(exist(_wsorder)) %THEN %DO;

               Data WORK._wsorder;
               Set WORK._wsorder;
                  Length wsname $ 8;
                  wsname = "&EMWS_name";
               Run;

               /* append this workspace info */
               Proc Datasets NOLIST;
                  APPEND Base= WORK._EMWS_NodeOrder
                   Data=WORK._wsorder;
               Run;
               Quit;
            %END;
         %END;

      %END; /*end for each workspace get node order */

      /* combine node order and view list */
      Proc Sort NODUPKEY Data= WORK._EMWS_NodeOrder
          Out=  WORK._EMWS_NodeOrder;
          By wsname NodeName;
      Run;
      Proc Sort Data= WORK._EM_Views
         Out=  WORK._EM_Views;
         By wsname NodeName;
      Run;
      Data WORK._EM_ViewOrder (KEEP=wsname location order path process RelPath);
         MERGE WORK._EM_VIEWS (in=a) WORK._EMWS_NodeOrder (in=b);
         BY wsname nodename;
         process=0;
         if a and b then output ;
      Run;
      %IF (&SYSERR ^= 0) %THEN %ABORT CANCEL;

      Proc Sort Data= WORK._EM_ViewOrder
          Out=  WORK._EM_ViewOrder;
          By order;
      Run;
      %IF (&SYSERR ^= 0) %THEN %ABORT CANCEL;

      /* process each view in workspace and node order */
      %LET viewStatus=more;
      %DO %WHILE ("&viewStatus"="more");
         %LET View_Targ=;
         Data WORK._EM_ViewOrder;
         Set WORK._EM_ViewOrder end=lastobs;
            KEEP wsname location order path process RelPath;
            retain acts 0;   /* stop if no action target found */
            if process=0 and not acts then do;
               call symput('View_Targ',strip(Path));
               call symput('View_Rel',strip(RelPath));
               call symput('WS_Name',strip(Wsname));
               call symput('WS_Loc',strip(Location));
               process=1;
               acts=1;
            end;

            /* at end of view order data if no actions
             *  remain then all views processed  */
            if (lastobs and not acts) then do;
               call symput('viewStatus','done');
            end;
         Run;

         %IF (&SYSERR ^= 0) %THEN %ABORT CANCEL;

         %IF (%LENGTH(&View_Targ)) %THEN %DO;
            %LET SYSCC=0; /* reset */
            %IF ("&_EM_TRACE" = "ON") %THEN
               %PUT Restoring view from &View_Rel;

            Libname &WS_Name "&WS_Loc";
            %include "&View_Targ";


            %IF (&SYSCC ^= 0) %THEN %DO;
               /* since the views are usually recreated
                * when the project is re-run, accept failure
                */
               %IF (%EVAL(&SYSCC > 4)) %THEN
                  %EM_MigrateProject_MigrateLog(WMSG= View restore failed &View_Targ);
                  %ELSE
                  %EM_MigrateProject_MigrateLog(WMSG= View restore RC = &SYSCC for &View_Targ);
               %LET SYSCC = 0; /* reset */
               %LET RDVrc = 4; /* accept as warning */
            %END;

         %END; /* end if View_Target */
      %END; /* end process each view */

      %IF %sysfunc(exist(WORK._wsorder)) %THEN %DO;
         Proc Delete Data=WORK._wsorder; Run;
      %END;
      %IF %sysfunc(exist(WORK._EM_VIEWS)) %THEN %DO;
          Proc Delete Data=WORK._EM_VIEWS; Run;
      %END;
%RDV_Exit:;
   %LET SYSCC = &RDVrc;
%Mend EM_MigrateProject_RestoreViews;


/*******************************************************************
 * EM_MigrateProject_WSnodeOrder - produces the workspace and node order data used
 *  to process views in the correct order.
 *
 ********************************************************************/
%Macro EM_MigrateProject_WSnodeOrder( EMWSpath, OutDSname);

   Libname WS "&EMWSpath";

   %IF (&SYSERR ^= 0) %THEN %DO;
      %PUT &SYSERRORTEXT;
      %ABORT CANCEL;
   %END;

   /* since OutDSname gets appended to, clear any old data */
   Proc Datasets LIB=WORK MEMTYPE=(data) NOLIST;
      Delete &OutDSname;
   Run;
   Quit;

   %LET NodesInDiagram = 0;    /* assume empty diagram */

    Data _NULL_;                /* check for empty diagram */
      dsid=open("WS.em_dgraph");
      if (dsid > 0) then do;
         nlobs=attrn(dsid,"nlobs");
         call symput('NodesInDiagram',nlobs);
         rc = close(dsid);
      end;
   Run;
                               /* if empty no output */
   %IF %EVAL(&NodesInDiagram <= 0) %THEN
      %GOTO NONODES;

      /* Set terminal nodes */
      Data dgraph;
      Set WS.em_dgraph;
      Drop from to;
      nodeName = upcase(from);
      child = upcase(to);
      process=0;
      termnode = 0;
      rootnode=1; /* just for now defalt to root node */
      level=0;
      /* node with no child are terminal nodes */
      if (missing(to)) then do;
         termnode = 1;
         level=1;
      end;
   Run;

   %IF &SYSERR ^= 0 %then %ABORT CANCEL;

   Libname WS CLEAR;   /* clear the libname */

   /*marking each node that has a parent leaving only root nodes =1 */
   %LET allChecked = N;
   /* search for non-rootnodes */
   %DO %WHILE ("&allChecked" = "N");
      %LET NodeTarg =;

      Data dgraph;
      Set dgraph end=Lastobs;;
         Length targ $ 32;
         Drop found targ;
         Retain found 0;
         targ='';
         /* publish next node name to check for parent */
         if (process < 1) and (not found=1) then do;
            call symput('NodeTarg',strip(nodeName));
            process=1; /* mark as checked */
            found=1;   /* mark as still active */
         end;

         /* if done end search for non-rootnodes */
         if (lastobs and not found) then do;
               call symput('allChecked','Y');
         end;
      Run;

      %IF &allChecked = "Y" %Then %GOTO DoneRTnodes;


      %IF (%LENGTH(&NodeTarg)) %THEN %DO;
             %LET NodeHasParent =;
         /* if a target node is a child */
         Data _NULL_;
         Set dgraph;
            Length targ $ 32;
            Drop found targ;
            Retain found 0;
            targ='';

            targ = symget('NodeTarg');
            /* if node is a child it must have a parent */
            if ( strip(targ) = child) then do;
                           /* if the node ever appears as a child
                            * rember this node has parent */
               call symput('NodeHasParent','1');
               STOP;
            end;
         Run;

         %IF (&NodeHasParent = 1) %THEN %DO;
            /* set rootnode=0 if target node has parent */
            Data dgraph;
            Set dgraph;
               Length targ $ 32;
               Length  hasParent $ 1;
               Drop found targ hasParent;
               Retain found 0;
               targ='';
               targ = symget('NodeTarg');
               hasParent = symget('NodeHasParent');
               /* find this node in the list and mark
                * it as Not a root node */
               if ( strip(targ) = nodeName) and
                  (strip(hasParent) = '1') then do;
                  rootnode=0;
               end;
            Run;
         %END; /* if has parent */
      %END;
   %END;
   %DoneRTnodes:;
   /* now all the root and terminal nodes flagged */

   /* start flow back trace with the terminal nodes */
   Data WORK._nextnodes WORK.dgraph;
   Set  WORK.dgraph end=Lastobs;
      Retain count 0;
      Drop count;

      if termnode = 1 then do;
         count= count +1;
         process = 2;
         output WORK._nextnodes;
      end;
      output WORK.dgraph;
   Run;

   Proc Sort Data=WORK.dgraph Out=WORK.dgraph;
      BY child;
   Run;

   /* The parents of the nodes in _nextnode become the nextnodes */
   %LET _MoreNodes = 1;
   %DO %WHILE (%eval(&_MoreNodes > 0));
      /* set exit value */
      %LET _MoreNodes = 0;
      /* save nextnodes in outDS in order */
      Proc Datasets NOLIST;
         APPEND Base= &OutDSname
                Data= WORK._nextnodes;
      Run;
      Quit;

      /* find ALL target node parents */
      /* save each node name as child for merge */
      Data WORK._children (Keep= child plevel);
      Set WORK._nextnodes;
         child = nodeName;
                 plevel=level;
      Run;

      Proc Sort Data=WORK._children Out=WORK._children;
               BY child;
      Run;

      /* Make list of parents
         where the previous nodes are the child put parent in
         the nextnodes list */
      Data WORK._nextnodes WORK.dgraph;
         MERGE WORK.dgraph (in=a)  Work._children (in=b);
            BY child;
         Retain count 0;
         Drop count plevel;

         if (a and b)  then do;
            level = plevel+1;
            process = 2;
            count=count+1;
            output WORK._nextnodes;
         end;

         /* record process and level changes */
         if (a) then
            output WORK.dgraph;

         /* set exit value */
         if count > 0 then do;
            call symput('_MoreNodes','1');
         end;
         else call symput('_MoreNodes','0');
      Run;

   %END;

   /* invert back-traced node order data */
   Proc Sort Data=&OutDSname Out=&OutDSname NODUPRECS;
      BY DESENDING level;
   Run;

   /* set easy to use order var */
   Data &OutDSname;
   Set &OutDSname;
   retain Order 0;
      Order = Order +1;
   Run;

%NONODES:;
   %IF %sysfunc(exist(WORK.Dgraph)) %THEN %DO;
     Proc Delete Data=WORK.Dgraph; Run;
   %END;
   %IF %sysfunc(exist(WORK._children)) %THEN %DO;
     Proc Delete Data=WORK._children; Run;
   %END;
   %IF %sysfunc(exist(WORK._nextnodes)) %THEN %DO;
     Proc Delete Data=WORK._nextnodes; Run;
   %END;

%Mend EM_MigrateProject_WSnodeOrder;

/*******************************************************************
 * EM_MigrateProject_DeleteFile - delete external file like old views or
 * transport code files.
 ********************************************************************/
%Macro EM_MigrateProject_DeleteFile(Fpath);

   FILENAME delFile "&Fpath";

   Data _NULL_ ;
       Length fname $ 256;
       fname = scan("&FPath",-1,"&_dsep");

       rc = fdelete('delFile');
       if (rc = 0 ) then do;
          if ("&_EM_TRACE" = "ON") then
             put "NOTE: File deleted, " fname;
          end;
       else
          put "WARNING: unable to delete, &Fpath" ;
   Run;

   FILENAME delFile CLEAR;
%Mend EM_MigrateProject_DeleteFile;

/*******************************************************************
 * EM_MigrateProject_MigrateLog - writes messages to the SAS log and 
 * and external file in the directory specified by the RooPath 
 * parameter of the EM_MigrateProjroot macro.
 ********************************************************************/
%Macro EM_MigrateProject_MigrateLog(NMSG=, WMSG=, EMSG=, MSG=);
   %LET logpath = &&_EM_ProjMigrate_Log;
   %LET filrf=msgLog;
   %LET rc=%SYSFUNC(filename(filrf,"&logpath"));
   %LET fid=%SYSFUNC(fopen(&filrf,a));
   %IF (&fid <= 0) %THEN %GOTO LOGERROR;

   %IF ("&NMSG" ^= "") %THEN
      %LET txt = NOTE: &NMSG..;
   %ELSE %IF "&WMSG" ^= "" %THEN %DO;
     %LET txt = WARNING: &WMSG..;
   %END;
   %ELSE %IF "&EMSG" ^= "" %THEN
     %LET txt = ERROR: &EMSG..;
   %ELSE %IF "&MSG" ^= "" %THEN
     %LET txt = &MSG.;
   /* ECHO to log */
   %PUT &txt;

   /* write to file */
   %LET rc=%SYSFUNC(fput(&fid,&txt));
   %LET rc=%SYSFUNC(fwrite(&fid));
   %LET rc=%SYSFUNC(fclose(&fid));
   %Let rc=%sysfunc(filename(filrf));

   %GOTO ENDLOG;
   %LOGERROR: %DO;
      %PUT ERROR: Open failed for log file.;
      %PUT %SYSFUNC(sysmsg());
   %END;
   %ENDLOG:;
%Mend EM_MigrateProject_MigrateLog;

/*******************************************************************
 * EM_MigrateProject_dsep - Determines the current file system separator and sets
 *    the global variable with the appropreate character.
 ********************************************************************/
%Macro EM_MigrateProject_dsep;
  %GLOBAL _dsep;
   %IF %SUBSTR(&sysscp, 1, 3)= WIN %THEN
       %LET _dsep=\;
   %ELSE
       %IF %SUBSTR(&sysscp, 1, 3)= DNT %THEN
           %LET _dsep=\;
   %ELSE
       %LET _dsep=/;
%Mend EM_MigrateProject_dsep;

%EM_MigrateProject_dsep;

/*******************************************************************
 * EM_MigrateProject_Compare - Compares EM project contents
 ********************************************************************/
%Macro EM_MigrateProject_Compare(BasePath= , CompPath= );
   %LET SYSCC = 0;

   %EM_MigrateProject_dsep; /* get file seperator */

   /* make list of restored project */
   %EM_MigrateProject_GetFileInfo(RootPath=&CompPath,ProjMeta=Restproj);

   /* make list of original project */
   %EM_MigrateProject_GetFileInfo(RootPath=&BasePath,ProjMeta=Orgproj);

   /* compare names */
   Data OrgNames;
   Set OrgProj;
   Keep Name Type;
   Run;

   Proc Sort Data= OrgNames out=OrgNames;
     BY DESENDING Name;
   Run;

   Data RestNames;
   Set RestProj;
   Keep Name Type;
      /* Don't keep migration artifacts */
      if (Type = "sto") or (Type = "stc") then GOTO Skip;;

      if (indexw(Name, "EMProjRESTORELog") ^= 1) and
         (indexw(Name, "EMProjPREPARELog") ^= 1) and
         (indexw(Name, "restored")^= 1) and
         (indexw(Name, "libdata")^= 1) and
         (indexw(Name, "prepared")^= 1)and
         (indexw(Name, "_trantxt")^= 1)
      then Output;

     Skip:;
   Run;

   Proc Sort Data= RestNames out=RestNames;
     BY DESENDING Name;
   Run;

   Proc Compare base=OrgNames compare=RestNames;
   Run;

   %PUT Compare rc SYSINFO = &SYSINFO;

%Mend EM_MigrateProject_Compare;
