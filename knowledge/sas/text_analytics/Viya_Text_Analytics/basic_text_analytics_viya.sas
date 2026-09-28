/* Reviews project start-up file */
/* Work based on Kaggle Competition https://www.kaggle.com/snap/amazon-fine-food-reviews */
options validvarname=any;
%global root_path;
%let root_path=/casdata/projects/enron;
%put &=root_path.;
%let git_path=&root_path./src;
%put &=git_path.;

/* 	Load Amazon fine Food Reviews from Kaggle
Currently not working with nfsshare. Loaded via GUI */
/*
proc import datafile="/nfsshare/casdata/projects/enron/input/Reviews.csv"
out=data.reviews
dbms=csv
replace;
getnames=yes;
run;
proc print data=data.reviews; run;
*/
/* Setup CAS and Libs */
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");
;
libname data "&root_path./data" compress=binary;
libname sasdata "/sasdata";
caslib _all_ assign;

/* Macro definitions */
%include "&git_path./macros.sas";
*%load_base_cas(lib=sasdata, dsin=news_u8, viyalib=public, dsviya=news);

/* Language identification currently throws an error. */
/*
proc cas;
session mySession;

builtins.loadActionSet /
actionSet="textManagement";
run;

textManagement.identifyLanguage /
table={caslib="PUBLIC", name="news"}
docId="key"
text="TEXT"
casout={caslib="CASUSER", name="news_language", replace="TRUE"};
run;

table.fetch /
table={caslib="CASUSER", name="news_language"};
run;

quit;
*/
data casuser.reviews;
	set public.reviews;
	review_length=length(Text);

	/* At least 5 voters per review. */
	if(HelpfulnessDenominator >=5);
	helpful=ifn(HelpfulnessDenominator > 0, (HelpfulnessNumerator / 
		HelpfulnessDenominator > 0.8), .);
run;

proc sql noprint;
	select count(Id) into :nrows from casuser.reviews;
quit;
%put &=nrows.;
/*
proc fedsql sessref=mySession noprint;
	drop table casuser.FreqOut;
	create table casuser.FreqOut as
		select Score, count(helpful) as Count, (count(helpful) / &nrows) as Percent from casuser.reviews
			group by Score;
quit;

proc cas;
   simple.freq /
      inputs={"helpful"},
      table={name="reviews", groupBy={name="Score"}}
      casOut={name="FreqOut", replace=true};
run;
   table.fetch / table="FreqOut";
run;
quit;
*/
options CASDATALIMIT=ALL;
proc freq data=casuser.reviews noprint;
	by score;
	tables helpful / out=casuser.FreqOut;
run;
title "Review helpfulness by rating";
proc sgplot data=casuser.FreqOut;
	vbar score / response=Count group=helpful groupdisplay=stack;
run;
title;

/* Create a 70% Training / 30% Validation simple random split.*/
proc cas;
	loadactionset "sampling";
	action srs result=r / table="Reviews" samppct=70 partind=true seed=1 
		output={casout={name="reviews_part", replace="TRUE"}, copyvars="ALL"};
	run;
	print r.SRSFreq;
	run;
	table.fetch / table="reviews_part";
	run;

	/* Defaul caslib set with session start-up, use short notation for name. */
	/*      table={caslib="CASUSER", name="reviews_part"};
	run;*/
quit;

/* Splitting training and validation sets into separate tables. At least 5 voters per review. */
proc fedsql sessref=mySession noprint;
	drop table casuser.reviews_training force;
	drop table casuser.reviews_validation force;
	create table casuser.reviews_training as select * from casuser.reviews_part 
		where _PartInd_=1;
	create table casuser.reviews_validation as select * from casuser.reviews_part 
		where _PartInd_=0;
	quit;

/* Basic flow of the modeling and scoring */
/* Train Data --> tpParse -> tpSpell -> tpAccum -> tmSVD -> tmAstore (AStore) -> smvTrain (AStore). */
/* Text Analytics term roles after parsing */
/*
Role	Meaning		Example	Language of Example
A 		Adjective 	Big 	English
N 		Noun 		Book 	English
V 		Verb 		Explain English
ADV 	Adverb 		Quickly English
CONJ 	Conjunction	With	English
DET		Determiner	The		English
PPOS	Adposition (Preposition or Postposition) Under English
PRO 	Pronoun 	She 	English
CLASS	Classifier (Grammatically required counter) 個 Chinese
INTJ	Interjection	Wow English
NUM		Number		Two		English
PTCL Particle (Nonindependent word that modifies grammatical feature of other word or phrase) 嗎 Chinese
PN 		Proper Noun England English
AFX		Independently listed affix éco French
*/

/* Text parsing */
proc cas;
	textParse.tpParse / table={name="reviews_training"} docId="ID" entities="std" 
		noungroups=True stemming=True tagging=True text="Text" outComplexTag=True 
		predefinedMultiterm=True language="English" offset={name="reviews_pos", 
		replace=True} parseConfig={name="reviews_config", replace=True};
	run;
	table.fetch / table="reviews_pos" sortby={"_document_", "_start_", "_end_"};
	run;
	table.fetch / table="reviews_config";
	run;
quit;

/* Spelling correction */
proc cas;
	builtins.loadActionSet / actionSet="textParse";
	run;
	textParse.tpSpell / table="reviews_pos" casOut={name="reviews_spell", 
		replace=TRUE};
	run;
	table.fetch / table="reviews_spell" sortby={"_document_", "_start_", "_end_"};
	run;
quit;

/* Using Synonyms */
data casuser.reviews_synonyms;
	infile datalines delimiter=',';
	length Term $13;
	input Term $ TermRole $ Parent $ ParentRole$;
	datalines;
tsp, N, teaspoon, N
tbsp, N, tablespoon, N
carb, N, carbohydrate, N
fridge, N, refrigerator, N
hot chocolate, nlpNounGroup, hot cocoa, nlpNounGroup
purchase, V, buy, V
tummy, N, stomach, N
tasty, A, delicious, A
yummy, A, delicious, A
yucky, A, disgusting, A
mom, N, mother, N
dad, N, father, N
begin, V, start, V
fast, A, quick, A
;
run;

/* Using Stop lists - https://github.com/igorbrigadir/stopwords/tree/master/en */
data casuser.reviews_stoplist;
	length Term $16;
	infile datalines;
	input Term $;
	datalines;
'd
'll
'm
're
's
've
a
aboard
about
above
according
accordingly
across
actually
after
afterwards
again
against
ago
ah
ain
all
almost
along
alongside
already
also
although
altogether
am
amid
amidst
among
amongst
an
and
another
any
anybody
anyhow
anyone
anyplace
anything
anyway
anyways
anywhere
apart
appreciate
appropriate
are
;
run;

/* Condense parent - term strucutre, i.e. term by document further for SVD projection and topic extraction.*/
proc cas;
	builtins.loadActionSet / actionSet="textParse";
	run;
	textParse.tpAccumulate / cellWeight="LOG", termWeight="entropy" reduce=10 
		complexTag=TRUE language="ENGLISH" offset="reviews_spell" 
		stopList="reviews_stoplist" synonyms="reviews_synonyms" 
		terms={name="reviews_outterms", replace=TRUE} 
		parent={name="reviews_outparents", replace=TRUE} child={name="reviews_child", replace=TRUE};
	run;
	table.fetch / table="reviews_outterms";
	run;
	table.fetch / table="reviews_outparents";
	run;
	table.fetch / table="reviews_child";
	run;
quit;

/* Perform SVD projection and topic extraction based on term by document matrix.*/
proc cas;
   loadactionset "textMining";
   action tmSvd;
   param
	  config="reviews_config"
      parent="reviews_outparents"
	  terms="reviews_outterms"
      k=100
	  norm="doc"
	  docPro={name="reviews_docPro_100", replace=TRUE}
	  scoreConfig={name="reviews_scoreConfig", replace=TRUE}
      topics={name="reviews_outtopics_100",replace=TRUE}
      termTopics={name="reviews_outtermtopics_100",replace=TRUE}
      u={name="reviews_svdu_100", replace=TRUE}
      numLabels=3
   ;

   action table.fetch /table="reviews_docPro_100"; run;
   action table.fetch /table="reviews_scoreConfig"; run;
   action table.fetch /table="reviews_outtopics_100"; run;
   action table.fetch /table="reviews_outtermtopics_100"; run;
   action table.fetch /table="reviews_svdu_100"; run;
quit;

proc cas;                                                    /*7*/ 
      loadactionset "textUtil"
      action tmAstore;
      param         
          documents={name="reviews_training"}
          docId="id"
          text="text"
          terms="reviews_outterms" 
          config="reviews_scoreConfig"
          termTopics="reviews_outtermtopics_100"
          topics={name="reviews_outtopics_100"} 
          saveState={name="reviews_tmAstore_100", replace=TRUE}
      ;
      run;
quit; 

/* Joining Document Projections to Input Data for use in Support Vector Machines Model */
proc fedsql sessref=mySession noprint;
	drop table casuser.docProJoin force;
	create table casuser.docProJoin{options replace=true} as
       	select D.*, T.Score, T.Summary, T.Text, /* T.votedHelpful, T.totalVotes, T.percent, */ T.helpful, T.review_length
       from reviews_docPro_100 D, casuser.reviews_training T
       where D._id_ = T.id;
quit;

/* Training SVM Model with Document Projections, Star Rating, and Review Length */
proc contents data=casuser.docprojoin out=contents noprint; run;
data contents;
	set contents;
	length new_name $32;
	new_name = cats('"',name,'"');
run;
proc sql noprint;
	select new_name into :docpros separated by ' ' from contents where(name like "_Col%");
quit;
%put &=docpros.;

/*
%macro predictors;
	proc sql noprint;
		select name into :docpros separated by ' ' from contents where(name like "_Col%");
	quit;
	%let N=&sqlobs.;
	%let preds = %str(%");
	%do i=1 %to &n.;
		%let docpro=%scan(&docpros.,&i.,' ');
		%put I=&i. &docpro.;
		preds = %sysfunc(catx(%str(%" %"),&preds.,&docpro.));
	%end;
	%sysfunc(cats(&preds.,%str(%")));
	%put &=preds.;
%mend predictors;
%predictors
*/

/* Training SVM Model with Document Projections, Star Rating, and Review Length */
proc cas;
    action svm.svmtrain /
        table="docProJoin"
        nominals={"helpful" "score"}
        inputs={&docpros. "score" "review_length"}
        target="helpful"
        saveState={name="reviews_svm_modell_all", replace=TRUE};
run;
quit;

/* Scored Document Projections on Validation Data with astore.score */
proc cas;
   loadactionset "aStore";
   action aStore.score /
      table="reviews_validation",
      out={name="reviews_validation_scored_out", replace=TRUE},
      copyVars={"id", "score", "text", "helpful", "review_length"},
      rstore="reviews_tmAstore_100";
run;
quit;

/* Score SVM Model - Doc Projections + Review Length + Star Rating. */
proc cas;
   loadactionset "aStore";
   action aStore.score /
      table="reviews_validation_scored_out",
      out={name="reviews_validation_scored_final", replace=TRUE},
      copyVars={"id", "helpful"},
      rstore="reviews_svm_modell_all";
run;
quit;

/* Assessing SVM Model - All Variables. NOTE: Assess values currently not meaningful. To be checked. */
proc cas;
   percentile.assess /
      epsilon=0.001
      maxIters=100
      nBins=100
      inputs="p_helpful1"
      response="helpful"
      event="1"   
	  includeLift=FALSE
      table="reviews_validation_scored_final"
/*      fitStatOut={name="reviews_validation_fitstats", replace=TRUE} */
      rocOut={name="reviews_validation_roc", replace=TRUE};
   run;
quit;       

/* Simple ROC Chart */
proc sgplot data=casuser.reviews_validation_roc;
  scatter x=_fpr_ y=_Sensitivity_;
  series x=_fpr_ y=_Sensitivity_;
run;

cas mySession terminate;