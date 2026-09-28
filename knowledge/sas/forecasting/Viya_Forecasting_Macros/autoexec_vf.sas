*Options source source2 mprint mlogic;

%let _first=YES;

/* Insert custom code after server connection here */
%let pathsep=/;
%let directory	=/opt/data;

/********************************************************************/
/*** Systemdefinitionen start										*/
/********************************************************************/

*Options source source2 mprint mlogic;
libname data_IN  "&directory.&pathsep.HPF-Engine&pathsep.Data_IN";
libname data_OUT "&directory.&pathsep.HPF-Engine&pathsep.Data_OUT";

/********************************************************************/
/*** Systemdefinitionen end											*/
/********************************************************************

/*****************************************************************************/
/*  Set the options necessary for creating a connection to a CAS server.     */
/*  Once the options are set, the cas command connects the default session   */ 
/*  to the specified CAS server and CAS port, for example the default value  */
/*  is 5570.                                                                 */
/*****************************************************************************

options cashost="<cas server name>" casport=<port number>;
cas;

/*****************************************************************************/
/*  Start a session named mySession using the existing CAS server connection */
/*  while allowing override of caslib, timeout (in seconds), and locale     */
/*  defaults.                                                                */
/*****************************************************************************/

cas myCaslib sessopts=(caslib=casuser timeout=1800 locale="en_US");

/*****************************************************************************/
/*  Create a default CAS session and create SAS librefs for existing caslibs */
/*  so that they are visible in the SAS Studio Libraries tree.               */
/*****************************************************************************/

cas; 
caslib _all_ assign;

/*****************************************************************************/
/*  Load SAS data set from a Base engine library (library.tableName) into    */
/*  the specified caslib ("myCaslib") and save as "targetTableName".         */
/*****************************************************************************/
%macro start;

data forecast;
	length date 8.;
run;

proc casutil;
	%if "&_first" eq "YES" %then %do;
		droptable casdata="forecast";
	%end;
	load data=forecast outcaslib="casuser"
	casout="forecast"  promote;
run;

data LONG_A;
	set DATA_IN.SEG_LONG_A;
	if a ne .;
	keep fc_var A date BU;
run;
data SHORT_A;
	set DATA_IN.SEG_SHORT_A;
	if a ne .;
	keep fc_var A  date;
run;

proc casutil;
	%if "&_first" eq "YES" %then %do;
		droptable casdata="LONG_A";
		droptable casdata="SHORT_A";
	%end;
	load data=LONG_A outcaslib="casuser"
	casout="LONG_A"  promote;
	
	load data=SHORT_A outcaslib="casuser"
	casout="SHORT_A" promote ;
run;
%mend start;
%start;
/*****************************************************************************/
/*****************************************************************************/
/*****************************************************************************/
