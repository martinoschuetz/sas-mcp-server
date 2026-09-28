/*options mlogic mprint mprintnest;*/
/*options nomlogic nomprint nomprintnest;*/

/* detect proper delim for UNIX vs. Windows */
%let delim=%sysfunc(ifc(%eval(&sysscp. = WIN),\,/));
%let pipe=%sysfunc(ifc(%eval(&sysscp. = WIN),&,|));

%global ROOTPATH graphicsout delim;

%let ROOTPATH=D:\Projects\Commerzbank\MSB BI\03_PoC;
%let graphicsout=&ROOTPATH.&delim.Graphics; 

/* Access the data */
libname input "&ROOTPATH.&delim.Input";
libname data "&ROOTPATH.&delim.Data";
libname formats "&ROOTPATH.&delim.Formats";
/*
libname results "&ROOTPATH.&delim.Results";
libname models "&ROOTPATH.&delim.Models";
*/
options fmtsearch=(formats);

/* Generates trace information from a DBMS engine. */
option sastrace=',,,d' sastraceloc=saslog nostsuffix;
