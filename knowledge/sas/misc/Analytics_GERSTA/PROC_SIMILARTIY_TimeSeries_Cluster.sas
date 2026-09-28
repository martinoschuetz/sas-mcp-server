options fullstimer;

/* Create Time Series Cluster */
data tmp;
	set sashelp.snacks;
	retain Series 0;

	if first.product then
		series+1;
	by product;
run;

proc sort data=tmp out=tmp2;
 by date;
run;

/* Transponieren, so dass pro Zeitreihe eine Spalte existiert (plus zusätzlicher Zeitstempel-Spalte DATE*/
proc transpose data=tmp2
	OUT=tmp3
    PREFIX=C_
	NAME=reihe
	LABEL=Etikett
;
	BY Date;
	ID series;
	VAR QtySold;
run;

/* Similarity berechnet alle Distanzen als Matrix (Statement outsum), wenn
   TARGET _numeric_ gesetzt wird.*/
proc similarity data=tmp3 out=_null_ outsum=summary;
      id date interval=day accumulate=total setmissing=0;
      target _numeric_ /normalize=standard measure=mabsdevmax;
run;

/* Setze erzeugte Datentabelle auf Typ DISTANCE, damit PROC CLUSTER sie richtig interpretiert */
data matrix(type=distance);
set summary;
drop _status_;
run;

ods graphics on;
/* PROC CLUSTER und PROC TREE zur Findung der Segmente */
proc cluster data=matrix plots=ALL outtree=tree method=average;
  id _input_;
run;
proc tree data=tree out=result nclusters=4; id _input_; run;
ods graphics off;
