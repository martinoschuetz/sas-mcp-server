/* First I uploaded a .sas7bdat to a SAS Content folder. */
/* (In this example, I uploaded inFolders.sas7bdat to My Folder location.) */

/* We can assign a fileref to files in the SAS Content folders */
filename in FILESRVC folderpath='/Users/cassmi/My Folder/' filename='inFolders.sas7bdat' recfm=n;

/* Location on the server file system to copy to */
filename out "~/filesystem.sas7bdat" recfm=n;
/* Or could copy straight to WORK library directory...  */
/* filename out "%sysfunc(getoption(work))\filesystem.sas7bdat" recfm=n; */
/* The use of RECFM=N is just to ensure that FCOPY doesn't add extra newlines to the end of the file. If that is harmless in this case, the RECFM=N can be omitted. */ 

/* Binary copy the file to a location on the server file system: */
%let x=%sysfunc(fcopy(in,out)); 

/* Since now on the server file system, can assign a library to it. */
libname blah '~/';
proc contents data=blah.filesystem;
run;