/*******************************************************************************
*
*	Define these inputs 
*
********************************************************************************/

/*Define the "library" folder in the SCA project */
libname dat 'C:\Users\adpilz\Documents\My SAS Files\9.4\gm_process_flow_discovery\library';

/*Specify a parent term from the SCA terms table*/
%let parent_term = airbag;

/*******************************************************************************
*
*	End define inputs, click Run
*
********************************************************************************/

/*Select the term and augment*/
proc sql;
	 create table word as
	 select distinct cats('"',Term,'"') as term_to_add
	 from dat.ALL_TERMS_DS
	 where PARENT_ID = (select PARENT_ID from dat.ALL_TERMS_DS where Term in ("&parent_term") and _ISPAR in ("+"))
	 order by term_to_add;
 quit;

/*Add some syntax*/
data word; set word end=eof;
	if _n_ = 1 then term_to_add = cats("(OR, ", term_to_add, ", ");
	else if eof then term_to_add = cats(term_to_add, ")");
	else term_to_add = cats(term_to_add, ",");
run;

/*Retrieve*/
proc sql;
	select * from word;
quit;
