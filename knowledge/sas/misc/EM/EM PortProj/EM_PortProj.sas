/**************************************************************/
/** ENTERPRISE MINER PROJECT CONVERSION:  Win32 -> Win64 ******/
/**************************************************************/
/** EXPERIMENTAL STATUS ** USE ONLY FOR TESTING ***************/
/**************************************************************/

/********************************************************************
 * EM_PortProj macro
 * Cports and Cimports Enterpise Miner projects
 *
 * SYNTAX:
 * %EM_PortProj(Action= ,   /* Required CPORT|CIMPORT */
 *           RootPath= , /* Required absolte path of project folder */
 *           DELETE=OFF, /* Optional remove CPORTED catalogs and data sets */
 *           NOEXEC=OFF  /* Optional No CPORT or delete action taken */
 *           );
 * USAGE:
 * First cport the project folder with
 *
 *   %EM_PortProj(Action=CPORT ,RootPath=C:\sasled\EMProj\Test1 );
 *
 * Then move the folder to the new system and cimport the folder with 
 * 
 *   %EM_PortProj(Action=CimPORT ,RootPath=C:\sasled\EMProj\Test1 );
 *
 *******************************************************************/
OPTIONS noMPRINT noMLOGIC;

/* Determine file system seperator */
%macro dsep;
	%global _dsep;

	%if %substr(&sysscp, 1, 3)= WIN %then
		%let _dsep=\;
	%else %if %substr(&sysscp, 1, 3)= DNT %then
		%let _dsep=\;
	%else %let _dsep=/;
%mend dsep;

%dsep;

%MACRO EM_PortProj( Action=       /* Required - CPORT or CIMPORT */
			,RootPath=     /* Required - Absolute path for project folder */
			,DELETE=OFF    /* Optional - ON = deletes cported files */
			,NOEXEC=OFF    /* Optional - ON = only produces the work data sets */
			);
	%LOCAL Port_Targ;
	%LOCAL FileCount;
	%put **************************************************************;
	%put ** ENTERPRISE MINER PROJECT CONVERSION:  Win32 -> Win64 ******;
	%put **************************************************************;
	%put ** EXPERIMENTAL STATUS ** USE ONLY FOR TESTING ***************;
	%put **************************************************************;
	%PUT Start EM_PortProj V3.1;

	/* start file hierarchy data set with target dir */
	Data WORK.EM_Proj;
		length Type $ 4;
		Length Path $ 1024;
		Length Status $ 5;
		Type = "root";         /* entry type root, dir or file       */
		Path = "&RootPath";    /* entry path (absolute)              */
		Status = "open";       /* flags processing state open|done   */
		Action = 0;            /* flags presents of actionable files */
		Fcount = 0;            /* count of actionable files          */
	Run;

	%PUT EM_PortProj: Step 1 -----------------------------------------------------;

	/* For every directory in the tree */
	%LET projSearch=more;

	%DO %WHILE ("&projSearch"="more");

		Data EM_Proj;
			Set EM_Proj end=lastobs;
			Keep Type Path Status Action Fcount;
			Length memname $ 256;
			Length parentPath $ 1024;
			Length mempath $ 1024;
			retain openDir 0;

			/* for each unprocessed dir in the data set */
			/* if done skip to next  dir */
			if ( status = "done") or (Type = "file") then
				do;
					Output;

					/* if no unprocessed dirs set done flag */
					if (lastobs and  not openDir) then
						call symput('projSearch','done');
				end;
			else
				do;
					/* process each open dir  */
					/* save parent attibutes */
					parentPath = path;
					parentType = type;
					parentAction = action;
					fcnt = 0;
					put "Searching path = " parentPath;

					/* open the parent dir and process it's members */
					rc=filename("emdir", parentPath);
					did=dopen("emdir");
					memcount=dnum(did);
					action=0;
					i= 1;

					do while (i<= memcount);
						memname=dread(did,i);

						/* build member path */
						mempath = cats(parentPath,"&_dsep");
						mempath = cats(mempath, memname);
						rc = filename("memref", mempath);

						if (rc ne 0) then
							do
							emsg=sysmsg();
								put emsg=;
								goto errexit;
							end;

						if (not fexist("memref")) then
							do;
								Error "ERROR: Listed directory member not found.";
								goto errexit;
							end;

						/* try to open memeber as directory */
						mdid=dopen("memref");

						/* if a directory opened */
						if (mdid > 0) then
							do;
								type = "dir";
								path = mempath;
								status= "open";
								action = 0;
								Output; /* output subdir info */
								openDir = 1; /* flag as unprocessed dir */

								/* Close the subdir */
								rc=dclose(mdid);

								/* clear the fileref */
								rc = filename("memref");
							end;
						else
							do;
								/* non directory members must be files */
								/* When CPORTing */
								%IF (%upcase(&Action)=CPORT) %THEN
									%DO;
										/* check for actionable files */
										dlen = kindex(memname, ".sas7bdat");

										if dlen > 0 then
											do;
												parentAction = 1;
												fcnt = fcnt +1;
												type = "file";
												path = mempath;
												status= "done";
												action = 1;
												Fcount = 1;
												Output; /* output file info */
											end;

										clen = kindex(memname, ".sas7bcat");

										if clen > 0 then
											do;
												parentAction = 1;
												fcnt = fcnt +1;
												type = "file";
												path = mempath;
												status= "done";
												action = 1;
												Fcount = 1;
												Output; /* output file info */
											end;
									%END;

								/* When cIMporting */
								%IF (%upcase(&Action)^=CPORT) %THEN
									%DO;
										tlen = kindex(memname, ".tpo");

										if tlen > 0 then
											do;
												parentAction = 1;
												fcnt = fcnt +1;
												type = "file";
												path = mempath;
												status= "done";
												action = 1;
												Fcount = 1;
												Output; /* output file info */
											end;
									%END;

								/* no need to close member open failed */
								/* clear the fileref */
								rc = filename("memref");
							end; /* end file processing */

						i+1; /* increment to try next member */
					end;/* end do members */

					/* close the parent dir */
					rc= dclose(did);

					/* save the parent path */
					path = parentpath;
					type = parentType;
					action = parentAction;
					status= "done";
					Fcount = fcnt;
					Output;
				end; /* each parent loop */

			goto normexit;
			errexit:
				call symput('projSearch','done');

			if (did ne 0) then
				rc=dclose(did);
			normexit:

				Run;

			%IF &SYSERR ^= 0 %then
				%ABORT CANCEL;
			%END; /* end prep loop */

			%PUT;
			%PUT EM_PortProj: Step 2 -----------------------------------------------------;

			/* Start Port loop */
			%LET portStatus=more;

			%DO %WHILE ("&portStatus"="more");
				%LET Port_Targ =;

		Data EM_Proj;
			Set EM_Proj end=lastobs;
			Keep Type Path Status Action Fcount;
			retain acts 0;
			retain fcnt 0;

			if ((Type = "dir") and ( action = 1) and (acts = 0)) then
				do;
					call symput('Port_Targ',strip(path));
					action = 0;
					acts = acts+1;
				end;

			/* if no actions set done flag */
			if (lastobs and  not acts) then
				do;
					call symput('portStatus','done');
				end;
		Run;

		%IF (%LENGTH(&Port_Targ)) %THEN
			%DO;
				%PUT &Action.ing SAS files in &Port_Targ.;
				Libname PRJ "&Port_Targ";

				%IF (%upcase(&Action)=CPORT) %THEN
					%DO;
						%IF (%upcase(&NOEXEC)=OFF) %THEN
							%DO;

								Proc Cport LIB= PRJ DATECOPY 
									MEMTYPE=ALL
									FILE="&Port_Targ&_dsep.lib.tpo";
								Run;

								%IF &SYSERR ^= 0 %then
									%ABORT CANCEL;

								%IF (%upcase(&DELETE) = ON) %THEN
									%DO;
										/* Delete all the cported catalogs and datasets */
										Proc Datasets LIB=PRJ MEMTYPE=(data catalog) KILL NOLIST;
										Quit;

										Run;

									%END;
							%END;
					%END;
				%ELSE
					%DO;
						%IF (%upcase(&NOEXEC)=OFF) %THEN
							%DO;

								Proc Cimport NEW
									INFILE="&Port_Targ&_dsep.lib.tpo"
									LIB= PRJ;
								RUN;

								%IF &SYSERR ^= 0 %then
									%ABORT CANCEL;
							%END;
					%END;

				%IF &SYSERR ^= 0 %then
					%ABORT CANCEL;
				Libname PRJ clear;
			%END;

		%IF &SYSERR ^= 0 %then
			%ABORT CANCEL;
			%END;

			%PUT;
			%PUT EM_PortProj: Step 3 -----------------------------------------------------;

			%IF (%upcase(&NOEXEC)=OFF) %THEN
				%LET Action = Processed;
			%ELSE %LET Action = Targeted;
			%PUT EM_PortProj: Files &Action ...;

			Data EM_Files;
				Set EM_Proj end=lastobs;
				Keep Type Path Status Action Fcount;
				retain fcnt 0;

				if (Type = "dir") then
					fcnt = fcnt + Fcount;

				if (Type = "file") then
					do;
						put "   " path;
						Output;
					end;

				if (lastobs) then
					do;
						call symput('FileCount',put(fcnt,Best8.));
					end;
			Run;

			%PUT EM_PortProj: &Action file count = %SYSFUNC(strip(&FileCount));

			%IF (%upcase(&NOEXEC)^=OFF) %THEN
				%PUT EM_PortProj: NOEXEC option is on. No files were ported.;
			%PUT NOTE: End EM_PortProj Macro;
			%put **************************************************************;
			%put ** ENTERPRISE MINER PROJECT CONVERSION:  Win32 -> Win64 ******;
			%put **************************************************************;
			%put ** EXPERIMENTAL STATUS ** USE ONLY FOR TESTING ***************;
			%put **************************************************************;
%MEND EM_PortProj;

/*%EM_PortProj(Action=CPORT,RootPath=C:\Projects\EM\test,DELETE=OFF,NOEXEC=ON);*/
/*%EM_PortProj(Action=CPORT,RootPath=C:\Projects\EM\test,DELETE=OFF,NOEXEC=OFF);*/
/*%EM_PortProj(Action=CPORT,RootPath=C:\Projects\EM\test,DELETE=ON,NOEXEC=OFF);*/
/*%EM_PortProj(Action=CPORT,RootPath=C:\Projects\EM\test);*/
/*%EM_PortProj(Action=CIMPORT, RootPath=C:\Projects\EM\test1);*/
