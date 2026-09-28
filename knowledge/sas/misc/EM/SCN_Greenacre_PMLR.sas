/*
https://communities.sas.com/t5/SAS-Data-Mining-and-Machine/Automatically-collapsing-levels-of-a-categorical-variable-in-SAS/td-p/370730

Automatically collapsing levels of a categorical variable in SAS EM

frupaul  

Hi everyone,

Is there a way of automatically collapsing levels of a categorical variable in SAS Enterprise miner (I dont want to do it using the replacement editor as this is a manual approach).

 

One way of doiing this in SAS enterprise guide is to use the greenacre's method. This collapses levels that lead to the least reduction in the chis square statistics, thereby leading to a resulting categorical variable that has a strong relationship to the target.

 

Could greenacre's method be performed in SAS Miner?

Thanks

*/
/*
Contributed by: Terry Woodfield

The following code has not been tested. Use it at your own risk.

This code implments Greenacre's method for consolidating the levels of
a categorical variable as presented in the SAS course, "Predictive
Modeling Using Logistic Regression," section 3.2, program pmlr03d02.sas.
For a description of categorical consolidation using a Decison Tree
node in SAS Enteprise Miner, see the SAS course, "Applied Analytics 
Using SAS Enterprise Miner," section 9.4.

This code is intended for use in a SAS Enterprise Miner SAS Code node.
For more information, see "SAS Enterprise Miner 13.1 Extension Nodes: 
Developer's Guide." You may also wish to consider the course, "Extending 
SAS Enterprise Miner with User-Written Nodes."
*/

/*
Hardcoded properties
The ConsolVar macro variable must be hardcoded by the user.
It contains the name of the categorical variable that you
want to consolidate.
*/
%global ConsolVar TargetVar;
%let ConsolVar=DemCluster;
%let Binary_Target=%scan(%EM_BINARY_TARGET,1,%str( ));

/*
SAS Enterprise Miner Specific Code
*/

%EM_REGISTER(KEY=LEVL,TYPE=DATA);
%EM_REGISTER(KEY=CHI,TYPE=DATA);
%EM_REGISTER(KEY=CLUS,TYPE=DATA);
%EM_REGISTER(KEY=CPRT,TYPE=DATA);
%EM_REPORT(KEY=CPRT,VIEWTYPE=DATA,
           DESCRIPTION=%str(Levels of &ConsolVar by Cluster),
           BLOCK=%str(Consolidation Plots),
           AUTODISPLAY=Y);
%EM_REGISTER(KEY=PLOT,TYPE=DATA);
%EM_REPORT(KEY=PLOT,VIEWTYPE=LINEPLOT,Y=logpvalue,
           X=numberofclusters,
           DESCRIPTION=%str(Plot of the Log of the P-Value by Number of Clusters),
           BLOCK=%str(Consolidation Plots),
           AUTODISPLAY=Y);
%EM_REGISTER(KEY=TREE,TYPE=DATA);
%EM_REPORT(KEY=TREE,VIEWTYPE=DENDROGRAM,
           BLOCK=%str(Consolidation Plots),
           DESCRIPTION=%str(Dendrogram of Consolidated Variable &ConsolVar), 
           NAME=_NAME_, 
           PARENT=_PARENT_, 
           HEIGHT=_RSQ_,
           AUTODISPLAY=Y);



/* 
   Plot the log p-values (logworth) against number of clusters. 
*/

/*
Code from PMLR41, section 3.2, pmlr03d02.sas,
converted to a Greenacre macro.
*/


%macro Greenacre(DSName=,CatVar=,TargetVar=);
   %local NumCLus;
   proc means data=&DSName noprint nway;
      class &CatVar;
      var &TargetVar;
      output out=&EM_USER_LEVL mean=prop;
   run;

   /* 
   Use ODS to output the ClusterHistory output object into a data set 
   named "cluster." 
   */

   ods output clusterhistory=&EM_USER_CLUS;

   proc cluster data=&EM_USER_LEVL method=ward outtree=&EM_USER_TREE;
                * plots=(dendrogram(vertical height=rsq));
      freq _freq_;
      var prop;
      id &CatVar;
   run;

   /* 
   Use the FREQ procedure to get the Pearson Chi^2 statistic of the 
   full &CatVar*&TargetVar table. 
   */

   proc freq data=&DSName noprint;
      tables &CatVar*&TargetVar / chisq;
      output out=&EM_USER_CHI(keep=_pchi_) chisq;
   run;

   /* 
   Use a one-to-many merge to put the Chi^2 statistic onto the clustering
   results. Calculate a (log) p-value for each level of clustering. 
   */

   data &EM_USER_PLOT;
      if _n_=1 then set &EM_USER_CHI;
      set &EM_USER_CLUS;
      chisquare=_pchi_*rsquared;
      degfree=numberofclusters-1;
      logpvalue=logsdf('CHISQ',chisquare,degfree);
   run;

   

   /* 
   Create a macro variable (&NumClus) that contains the number of clusters
   associated with the minimum log p-value. 
   */

   proc sql noprint;
      select NumberOfClusters into :NumClus
      from &EM_USER_PLOT
      having logpvalue=min(logpvalue);
   quit;

   proc tree data=&EM_USER_TREE nclusters=&NumClus out=&EM_USER_CPRT noprint;
      id &CatVar;
   run;

   proc sort data=&EM_USER_CPRT;
      by clusname;
   run;

   title1 "Levels of &CatVar by Cluster";
   proc print data=&EM_USER_CPRT;
      by clusname;
      id clusname;
   run;
   title1 ;

   /* 
   The DATA Step creates the scoring code to assign the categories to a cluster. 
   */

   filename catclus "&EM_FILE_EMFLOWSCORECODE";

   data _null_;
      file catclus;
      set &EM_USER_CPRT end=last;
      if _n_=1 then put "select (&CatVar);";
      put "  when ('" &CatVar +(-1) "') &CatVar._clus = '" cluster +(-1) "';";
      if last then do;
         put "  otherwise &CatVar._clus = 'U';" / "end;";
      end;
   run;

   data &EM_EXPORT_TRAIN;
      set &DSName;
      %include catclus;
   run;
   %if ("&EM_IMPORT_VALIDATE" ne "") and
       (%sysfunc(exist(&EM_IMPORT_VALIDATE)) or
        %sysfunc(exist(&EM_IMPORT_VALIDATE, VIEW))) %then %do;
      data &EM_EXPORT_VALIDATE;
         set &EM_IMPORT_VALIDATE;
         %include catclus;
      run;
   %end;
   %if ("&EM_IMPORT_TEST" ne "") and
       (%sysfunc(exist(&EM_IMPORT_TEST)) or
        %sysfunc(exist(&EM_IMPORT_TEST, VIEW))) %then %do;
      data &EM_EXPORT_TEST;
         set &EM_IMPORT_TEST;
         %include catclus;
      run;
   %end;
   %if ("&EM_IMPORT_SCORE" ne "") and
       (%sysfunc(exist(&EM_IMPORT_SCORE)) or
        %sysfunc(exist(&EM_IMPORT_SCORE, VIEW))) %then %do;
      data &EM_EXPORT_SCORE;
         set &EM_IMPORT_SCORE;
         %include catclus;
      run;
   %end;



%mend Greenacre;

%Greenacre(DSName=&EM_IMPORT_DATA,CatVar=&ConsolVar,TargetVar=&Binary_Target);



