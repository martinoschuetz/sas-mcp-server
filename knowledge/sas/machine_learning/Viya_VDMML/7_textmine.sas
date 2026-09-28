/************************************************************************/
/* This code example illustrates the use of PROC TEXTMINE for           */
/* identifying important terms and topics in a document collection.     */
/*                                                                      */
/* PROC TEXTMINE parses the news data set to                            */
/*   1. generate a dictionary of important terms                        */
/*   2. generate a collection of important topics                       */
/*                                                                      */
/* The OUTTERMS= option specifies the terms dictionary to be created.   */
/* The OUTTOPICS= option specifies the SAS data set to contain the      */
/* number of topics specified by the K= option. The user can peruse the */
/* TERMS and TOPICS data sets to gain insight about the document        */
/* collection.                                                          */
/*                                                                      */
/* PROC TMSCORE allows the user to score new document collections       */
/* based on training performed by a previous PROC TEXTMINE analysis.    */
/************************************************************************/

/************************************************************************/
/* Setup and initialize for later use in the program                    */
/************************************************************************/
/* Specify a libref to the input tables */
libname locallib '/opt/sasinside/DemoData';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;


/************************************************************************/
/* Load data into CAS                                                   */
/************************************************************************/
%if not %sysfunc(exist(mycaslib.news)) %then %do;
  proc casutil;
    load data=locallib.news casout="news";
  run;
%end;

%if not %sysfunc(exist(mycaslib.engstop)) %then %do;
  proc casutil;
    load data=locallib.engstop casout="engstop";
  run;
%end;


/************************************************************************/
/* 1. Parse the documents in table news and generate the                */
/*    term-by-term matrix                                               */
/* 2. Perform dimensionality reduction via SVD, and                     */
/* 3. Perform topic discovery based on SVD                              */
/************************************************************************/
proc textmine data=mycaslib.news;
  doc_id key;
  var text;
  /* part (1) */
  parse reducef=2 entities=std stop=mycaslib.engstop
        outterms=mycaslib.terms outparent=mycaslib.parent
        outconfig=mycaslib.config;
  /* part (2) and (3) */      
  svd k=10 svdu=mycaslib.svdu outdocpro=mycaslib.docpro
      outtopics=mycaslib.topics;
run;


/************************************************************************/
/* Print results                                                        */
/************************************************************************/
proc sql;
  create table terms as
  select * from mycaslib.terms 
  order by numdocs descending;
quit;

/* Show the 10 topics found by PROC TEXTMINE */
proc print data=mycaslib.topics;
  title '10 Topics found by PROC TEXTMINE';
run;

/* Show the top 10 entities that appear in the news */
proc print data=terms(obs=10);
  where attribute='Entity';  
  title 'Top 10 entities that appear in the news';
run;

/* Show the top 10 noun terms that appear in the news */
proc print data=terms(obs=10);
  where role='Noun';  
  title 'Top 10 noun terms that appear in the news';
run;

/* Show the structured representation of the first 5 documents */
proc print data=mycaslib.docpro(obs=5);
  title 'Stuctured representation of first 5 documents';
run;
title;


/************************************************************************/
/* Score new text data                                                  */
/************************************************************************/
proc tmscore data=mycaslib.news svdu=mycaslib.svdu 
     config=mycaslib.config terms=mycaslib.terms
     svddocpro=mycaslib.score_docpro outparent=mycaslib.score_parent;
  var text;
  doc_id key;
run;
