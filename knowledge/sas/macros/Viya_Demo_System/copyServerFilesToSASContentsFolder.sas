/* A macro that will copy files from the server file system to SAS Content folders... */

options SERVICESBASEURL="http://dach-viya-smp.sas.com:7980"

%macro CopyFilesToSASContentsFolder(directorySource, folderDestination);
	%let filrf=mydir;
	%let rc=%sysfunc(filename(filrf,"&directorySource")); /* assign dir name */
	%let did=%sysfunc(dopen(&filrf)); /* open directory */
	%let lstname=; /* clear filename macro var */
	%let memcount=%sysfunc(dnum(&did)); /* get # files in directory */

	%if &memcount > 0 %then /* check for blank directory */

		%do i=1 %to &memcount; /* start loop for files */
			%let lstname=%sysfunc(dread(&did,&i)); /* get file name to process */

			/* Location on the server file system to copy from */
			filename _bcin "&directorySource.&lstname" recfm=n; /* RECFM=N needed for a binary copy */

			/* Folder in SAS Content to copy files to */
			filename _bcout FILESRVC folderpath="&folderDestination" filename="&lstname" recfm=n; /* RECFM=N needed for a binary copy */

			data _null_;
				length msg $ 384;
				rc=fcopy('_bcin', '_bcout');

				if rc=0 then
					put 'Copied _bcin to _bcout.';
				else
					do;
						msg=sysmsg();
						put rc= msg=;
					end;
			run;

			filename _bcin clear;
			filename _bcout clear;
		%end;

		%let rc=%sysfunc(dclose(&did)); /* close directory */
%mend CopyFilesToSASContentsFolder;

%CopyFilesToSASContentsFolder(/home/sasdemo01/Codes/SAS/, /Users/sasdemo01/My Folder/Codes/SAS);
