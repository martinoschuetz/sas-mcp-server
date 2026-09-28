libname a "D:\DATEN\QUELLEN";

data tmp;
 set a.telkodata2;
 drop marketing planwerte preisindex;
 where umsatz ne .;
run;


proc sort data=tmp out=tmp2;
 by channel segment tariftyp tarif;
run;

proc stdize data=tmp2 out=tmp3 method=sum ;

      var umsatz;
      by channel segment tariftyp tarif;
   run;


PROC TRANSPOSE DATA=tmp3 OUT=tmp4
	PREFIX=M_
	NAME=Quelle
	LABEL=Etikett
;
	BY channel segment tariftyp tarif;
	ID zeitstempel;
	VAR umsatz;
RUN; 

data tmp4;
 set tmp4;
 TS_ID=_N_;
 run;

 data a.Timeseries_Cluster;
  set tmp4;
  run;

