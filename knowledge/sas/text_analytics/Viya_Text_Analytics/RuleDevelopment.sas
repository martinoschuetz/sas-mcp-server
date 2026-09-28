options casport=5570 cashost="centis";   /*1*/
cas casauto;
libname mycas cas; 

data mycas.concept_rules;                           /*2*/
   length config $100 ;
   infile datalines delimiter='|' missover;
   input config$;
   datalines;
    	ENABLE:HIGH_PRIORITY
    	FULLPATH:HIGH_PRIORITY:Top/HIGH_PRIORITY
    	PRIORITY:HIGH_PRIORITY:10
    	CASE_INSENSITIVE_MATCH:HIGH_PRIORITY
    	CLASSIFIER:HIGH_PRIORITY: sentiment   
   ;
run;

proc cas;                                           /*3*/
   
   builtins.loadActionSet /                         /*4*/
      actionSet="textRuleDevelop";
                           
   textRuleDevelop.compileConcept /                 /*5*/
      casOut={name="outli", replace=TRUE}
      config="config"
      table={name="concept_rules"};
   run;

quit;              

cas casauto terminate; 