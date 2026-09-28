/**************************************************/
/**   program to find nearest 10 crimes for given seed */
/*******************************************************/

libname crime1 'C:\temp\Crime\Workspaces\EMWS';



%MACRO score(filein=,fileout=,crimeid=,id_column=, num=) ;


/* create seed file */
data seedfile;
  set &filein;
  if &id_column = &crimeid ;
run;

/*find distance from seed to points */
proc fastclus data=&filein seed = seedfile out=close
maxclusters=1 maxiter=0 ;
var _svd_1 -- _svd_10;
run;

PROC RANK DATA = close
	TIES=MEAN
	OUT=ranks;
	VAR distance;
    RANKS rank_dist ;
RUN;

data &fileout (keep = &id_column distance rank_dist);
  set ranks;
  if rank_dist <= &num;
  /*if distance < .00001 then marker = "Y"; else marker ="N";*/
run;

/*
proc candisc data=ranks2 out=Can noprint;
var _svd_1 -- _svd_10;
run;


proc sgplot data=Can;

scatter y=_svd_2 x=_svd_1  ;
run;*/

%mend;

%score(filein = crime1.text_documents, fileout=test1,crimeid = 4,id_column=crimeid, num=10);
%score(filein = crime1.text_documents, fileout=test2,crimeid = 10,id_column=crimeid, num=4);
%score(filein = crime1.text_documents, fileout=test3,crimeid = 3,id_column=crimeid, num=5);
%score(filein = crime1.text_documents, fileout=test4,crimeid = 15,id_column=crimeid, num=8);
