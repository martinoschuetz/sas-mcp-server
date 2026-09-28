/* Example Programme for K-Nearest Neighbor classifier with PROC DISCRIM */

data iris_score;
 set sashelp.iris;
run;

data iris_train;
 set sashelp.iris;
 if ranuni(3333)>0.3 then delete;
  if ranuni(222)>0.5 then X1='Yes'; else X1='NO';
 if x1='NO' then x2=0; else x2=1;
run;
data iris_validate;
 set sashelp.iris;
 if ranuni(3333)<=0.3 then delete;

 if ranuni(222)>0.5 then X1='Yes'; else X1='NO';
 if x1='NO' then x2=0; else x2=1;
run;


proc discrim data = iris_train testdata=iris_score test = iris_validate out=_score1 testout = _score2 method = npar k = 5 testlist;
class x2 ;
var SEPALLENGTH PETALLENGTH PETALWIDTH SEPALWIDTH;
run; 