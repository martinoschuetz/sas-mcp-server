/* PREREQUISITES:
 *	+ Visual Text Analytics license
 *	+ The following code can be run in SAS Studio but there is no corresponding SAS Studio Task 
 */

/* Connect to CAS */
/** ----- FILL IN YOUR CAS SERVER BELOW (e.g. pdcesx23001.exnet.sas.com) ---- */
cas sascas1 host="<YOUR CAS SERVER>" port=5570;
libname sascas1 cas sessref=sascas1 datalimit=all;

options noquotelenmax;

/* Setup training data */
data sascas1.simple;
  infile datalines delimiter='|';
  length word $300;
  length pos $100;
  input word$ pos$;
  datalines;
    ["object", "oriented", "programming"]|["n", "adj", "n"]
    ["I", "like", "programming"]|["pron", "v", "n"]
  ;
run;

/* Train a CRF model */
proc cas;
  loadactionset "crf";
  session sascas1;
  action crf.crfTrain;
  param
     table="simple"
     target="pos"
     template="word[0],word[-1]/word[0],word[-1]/word[0]/word[1],word[-1]/word[1],word[0]/word[1],word[-1],word[1]"
     model={
        template={name="template", replace=true},
        label={name="label", replace=true},
        attr={name="attr", replace=true},
        feature={name="feature", replace=true},
        attrfeature={name="attrfeature", replace=true}
     }
  ;
  run;
quit;

/* Setup testing data */
data sascas1.simple_s;
  infile datalines delimiter='|';
  length word $300;
  input word$;
  datalines;
    ["I", "like", "debugging"]
    ["We", "like", "programming"]
    ["I", "like", "object", "oriented", "programming"]
  ;
run;

/* Score testing data */
proc cas;
  loadactionset "crf";
  session sascas1;
  action crf.crfScore;
  param
     table="simple_s"
     target="mytag"
     model={
        template="template",
        label="label",
        attr="attr",
        feature="feature",
        attrfeature="attrfeature"
     }
     casOut={name="crf_score_out", replace=true}
  ;
  run;
  action table.fetch /
     table={name="crf_score_out"}
     to=20;
  run;	
quit;