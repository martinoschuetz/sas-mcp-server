options cashost="centis" casport=5570;                /*1*/
cas casauto;
libname mycas cas;

data mycas.my_data_to_train;                                     /*2*/
   infile datalines delimiter='|' missover;
   length word $ 150 tag $ 150;
   input word$ tag$;
   datalines;
   ["This", "award", "is", "presented", "to", "Sam", "in", "recognition", "of", "the", "extraordinary", "work","done", "in", "2017", "."]|["DET", "N", "V", "V", "PPOS", "PN", "PPOS", "N", "PPOS", "DET", "A", "N", "A", "PPOS", "digit", "sep"]
   ;
run;

data mycas.my_data_to_score;                                     /*3*/
   infile datalines delimiter='|' missover;
   length word $ 200;
   input word$;
   datalines;
   ["Sam", "'s", "work", "has", "been", "recognized", "by", "his", "coworkers", "and", "managers", "."]
   ;
run;

proc cas;                                                  /*1*/

   loadactionset "conditionalRandomFields";                /*2*/
   run;

   conditionalRandomFields.crfTrain /                      /*3*/
      model={attr={name="crf_attr", replace=TRUE},
             attrfeature={name="crf_attrfeature", replace=TRUE},
             feature={name="crf_feature", replace=TRUE},
             label={name="crf_label", replace=TRUE},
             template={name="crf_template", replace=TRUE}
            }
      nloOpts={optmlOpt={maxIters=1000}} 
      table={name="my_data_to_train"}
      target="tag"
      template="word[-1],word[0],word[1],word[-1]/word[0],word[0]/word[1],word[-1]/word[1]";
   run;
   
   table.fetch /                         /*1*/
      table={name="crf_template"}; 
   run;

   table.fetch /                         /*2*/
      table={name="crf_label"}; 
   run;

   table.fetch /                         /*3*/
      table={name="crf_attr"}; 
   run;
   
   table.fetch /                         /*4*/
      table={name="crf_feature"}; 
   run;

   table.fetch /                         /*5*/
      table={name="crf_attrfeature"}; 
   run;

 conditionalRandomFields.crfScore /                  /*1*/
      casOut={name="crf_Score_Out", replace=TRUE}
      model={attr={name="crf_attr"},
             attrfeature={name="crf_attrfeature"},
             feature={name="crf_feature"},
             label={name="crf_label"},
             template={name="crf_template"}
            }
      table={name="my_data_to_score"}
      target="label";
   run;

   table.fetch /                                       /*2*/
      table="crf_Score_Out"; 
   run;

quit;                      

cas casauto terminate;