options casport=5570 cashost="centis"; 

cas mySession;
libname mycas cas;

caslib _all_ assign;

data mycas.CarNominations;
infile datalines delimiter='|' missover;
length text $70 ;
input text$ i;
datalines;
   The Ford Taurus is the World Car of the Year. |1
   Hyundai won the award last year. |2
   Toyota sold the Toyota Tacoma in bright green. |3
   The Ford Taurus is sold in all colors except for lime green. |4
   The Honda Insight was World Car of the Year in 2008. |5
   ;
run;


proc textmine data=mycas.CarNominations;
doc_id i;
var text;
parse
   termwgt    = ENTROPY 
   cellwgt    = LOG
   reducef    = 1
   entities   = std
   outparent  = mycas.outparent
   outterms   = mycas.outterms
   outchild   = mycas.outchild
   outconfig  = mycas.outconfig
   ;
select "PPOS" "DET" "PN"/ignore;
select "nlpDate"/group="entities" ignore;
run;

data outterms; set mycas.outterms; run;
proc print data= outterms; run;

cas mySession terminate;