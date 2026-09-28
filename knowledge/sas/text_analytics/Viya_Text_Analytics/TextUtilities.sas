options cashost="centis" casport=5570;              /*1*/
cas casauto; 
libname mycas cas;

data mycas.reviews;                                            /*2*/
   infile datalines delimiter='|' missover;
   length text $300 category $20;
   input text$ positive category$ did;
   datalines;
    This is the greatest phone ever! love it!|1|electronics|1
    The phone's battery life is too short and screen resolution is low.|0|electronics|2
    The screen resolution is low, but I love this tv.|1|electronics|3
    The movie itself is great and I like it, although the resolution is low.|1|movies|4
    The movie's story is boring and the acting is poor.|0|movies|5
    I watched this movie on tv, it's not good on a small screen. |0|movies|6
    watched the movie first and loved it, the book is even better!|1|books |7
    I like the story in this book, they should put it on screen.|1|books|8
    I love the author, but this book is a waste of time, don't buy it.|0|books|9
;
run;
                              
proc cas;                                                      /*3*/
loadactionset 'textMining';
tmMine / docId="did"
         documents="reviews" 
         entities="NONE"
         nounGroups=FALSE
         offset={name="pos", replace=TRUE}
         reduce=1
         stemming=FALSE
         tagging=FALSE
         terms={name="terms", replace=TRUE}
         text="text";
run;
quit;
    
proc cas;                                                      /*4*/
loadactionset 'textUtil';                               
textUtil.tmcooccur / cooccurrence={name="cooc", replace=TRUE}
                     maxDist=5
                     minCount=0
                     offset={name="pos"}
                     ordered=FALSE
                     terms={name="terms"}  
                     useParentId=TRUE;
run;
quit;

/* calculate word vector representation, a.k.a. word embedding */   
proc cas;                                               
tmSvd / count="_association_"
        docId="_termid2_"
        maxK=5
        parent="cooc" 
        termId="_termid1_"
        wordPro={name="wordPro", replace=TRUE};
run;

loadactionset 'fedsql';                                        /*5*/
execDirect / casout={name='wordEmbedding', replace=True}
            query='select t._term_, d.* from wordPro d, terms t where d._termnum_=t._termnum_';
fetch / table='wordEmbedding';
run;
quit;


/***********************************/

proc cas;
   loadactionset "textMining";                           /*3*/
   action tmMine;
   param
   docId="did"
   documents={name="reviews"}
   text="text"
   terms={name="terms", replace=TRUE}
   reduce=1
   k=3
   wordPro={name="wordpro", replace=TRUE}
;
action table.fetch /table="wordpro", orderBy="_TermNum_"; run;
action table.fetch /table="terms", orderBy="_TermNum_"; run;
run;
quit;

proc cas;
   loadactionset "textUtil";                             /*4*/
   action tmFindSimilar;
   param
   table='wordpro' 
   termnum="7"
   nSVD="3"
   casout={name="casout", replace=TRUE}
   prefix="col"
;
action table.fetch /table="casout", sortby={{name='_similar_', order='descending'}}; run;
run;
quit;

proc cas;
   fedSql.execDirect/                                    /*5*/
   casout={name="outSimilarTerms", replace=TRUE} 
   query="select a._term_,  b.*
          from (select * from terms where _ispar_ != '.') a join casout b 
          on a._termnum_ =b._termnum_ ";
   action table.fetch /table="outSimilarTerms", sortby={{name='_similar_', order='descending'}}; run;
run;
quit;

cas casauto terminate;