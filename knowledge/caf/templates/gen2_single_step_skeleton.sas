/* Generation 2 Declarative CAF Step Skeleton
   NOTE: Never write literal question-mark substitution tokens in comments!
*/

OPTION SPOOL;
%afi_caf_preprocess(?g_cas, ?analysisID);

/* Connect a CAS libref for in-CAS analytics */
libname caswork cas sessref=mySession;

/* Safely convert comma-separated MULTISELECT parameter G_INPUTVARS to space-delimited list */
%global G_INPUTVARS_SPACE;
%let G_INPUTVARS_SPACE = %sysfunc(tranwrd(%superq(G_INPUTVARS), %str(,), %str( )));

/* Perform distributed computation in CAS */
proc means data=&g_caf_input_table. noprint;
   var &G_INPUTVARS_SPACE.;
   output out=work.SUMMARY mean= std= / autoname;
run;

/* Publish output contract (use build_output_contract MCP tool to generate)
   work.SUMMARY publishes token {{.SUMMARY}} for DataSource/@label and CasResource/@table
*/
%let g_output_table_1 = work.SUMMARY;
%afi_caf_postprocess;
