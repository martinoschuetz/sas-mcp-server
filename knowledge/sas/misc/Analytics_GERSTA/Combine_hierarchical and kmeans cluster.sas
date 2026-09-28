title2 'By Ward''s Method';
ods graphics on;

proc cluster data=sashelp.iris method=ward print=15 ccc pseudo outtree=tmp ;
   var petal: sepal:;
   copy species;
   
run;

proc sql noprint; select _ncl_ into: ncl from tmp where (_ccc_=select min(_ccc_) from tmp); quit;
%put ncluster=&ncl;

proc tree noprint data=tmp ncl=3 out=out ncl=3 ;
   copy petal: sepal: species;

run;

proc means noprint data=out;
output out=centroids mean=;
class cluster;
run;

data centroids;
 set centroids;
 where _Type_=1;
 drop _type_ _freq_;
run;

proc fastclus data=sashelp.iris 
seed=centroids maxc=&ncl maxiter=20
out=finalsol;
var petal: sepal:;
run;