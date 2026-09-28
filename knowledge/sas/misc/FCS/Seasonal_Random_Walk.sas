libname fcs "D:\Data\FCS";

/*Model 9: RANDWALK, Label: Y ~  D=(1)  NOINT */
Proc HPFARIMASPEC
	MODELREPOSITORY = fcs.random_walk
	SPECNAME=RandomWalk
	SPECLABEL="Random Walk"
;
	FORECAST TRANSFORM = NONE
		NOINT 
		DIF = ( 1 );
	ESTIMATE 
		METHOD=CLS 
		CONVERGE=0.0010 
		MAXITER=50 
		DELTA=0.0010 
		SINGULAR=1.0E-7;
run;

/* Model 10: RANDWALK, Label: Y ~  D=(1 s)  NOINT */
Proc HPFARIMASPEC
	MODELREPOSITORY = fcs.random_walk
	SPECNAME=RandomWalk_Seasonal
	SPECLABEL="Seasonal Random Walk"
;
	FORECAST TRANSFORM = NONE
		NOINT 
		DIF = ( 1 s );
	ESTIMATE 
		METHOD=CLS 
		CONVERGE=0.0010 
		MAXITER=50 
		DELTA=0.0010 
		SINGULAR=1.0E-7;
run;


/* Specification of model list. Usually to be used if the filling degree is less than 0.33 */
Proc HPFSELECT
	MODELREPOSITORY = fcs.random_walk
	SELECTNAME=RandomWalk
	SELECTLABEL="Seasonal Randomwalk"
;
	/* These parameters have no meaning if integrated into Forecast Studio */
	SELECT
		HOLDOUT=0
		HOLDOUTPCT=100.0
		CRITERION=MAE;

	/* Reference by model name */
	SPEC RandomWalk;
	SPEC RandomWalk_Seasonal;
run;
quit;