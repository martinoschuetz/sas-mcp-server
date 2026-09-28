/*
	They may be referring to querying the LASR internal tables _T_LASRMEMORY and _T_TABLEMEMORY.
	Example code is below and it seems that the text in the where clause is
	case sensitive if you decide to use it.
	The example uses the summary action to total the server and/or
	table metrics across the distributed environment. 
	So the SUM column is your total for all the servers in the environment
	or your where clause.   The FETCH action will tell you the metrics per machine.
*/

libname lasrdata sasiola tag=hdp02 port=10012 verbose=yes;

proc imstat;
  table lasrdata._T_LASRMEMORY;
  /*where hostname eq 'eeclxvm07.unx.sas.com';*/
  fetch _ALL_ /* from=1 to=100 */;
  summary ;
  run;
quit;

proc imstat;
  table lasrdata._T_TABLEMEMORY;
  /*where tableName eq 'HDP02.AUTO_POLICY_TEXT';*/
  fetch _ALL_ /* from=1 to=100 */;
  summary / groupby=(tablename);
  run;
quit;

