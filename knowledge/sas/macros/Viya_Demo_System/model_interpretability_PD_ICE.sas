/*The macro requires the following input parameters:
- dataset: Specify the training set.
- target: Specify the target variable to use in the predictive model.
- PDVars: For one-way plots, specify one variable; for two-way plots, specify two model variables.
- otherIntervalInputs: Specify the complementary model variables whose measurement level is interval.
- otherClassInputs: Specify the complementary model variables whose measurement level is nominal or binary.
- scoreCodeFile: Specify the score code from the machine learning model.
- outPD: Name the output data set to contain the PD function.
*/
%macro PDfunction( dataset=, target=, PDVars=, otherIntervalInputs=, otherClassInputs=, scoreCodeFile=, outPD= );
	%let PDVar1 = %sysfunc(scan(&PDVars,1));
	%let PDVar2 = %sysfunc(scan(&PDVars,2));
	%let numPDVars = 1;

	%if &PDVar2 ne %str() %then
		%let numPDVars = 2;

	/*Obtain the unique values of the PD variable */
	proc summary data = &dataset.;
		class &PDVar1. &PDVar2.;
		output out=uniqueXs %if &numPDVars = 1 %then

			%do;
				(where=(_type_ = 1))
			%end;

		%if &numPDVars = 2 %then
			%do;
				(where=(_type_ = 3))
			%end;
		;
	run;

	/*Create data set of complementary Xs */
	data complementaryXs;
		set &dataset(keep= &otherIntervalInputs. &otherClassInputs.);
		obsID = _n_;
	run;

	/*For every observation in uniqueXs, read in each observation from complementaryXs */
	data replicates;
		set uniqueXs (drop=_type_ _freq_);

		do i=1 to n;
			set complementaryXs point=i nobs=n;

			%include "&scoreCodeFile.";
			output;
		end;
	run;

	/*Compute average yHat by replicate*/
	proc summary data = replicates;
		class &PDVar1. &PDVar2.;
		output out=&outPD. %if &numPDVars = 1 %then

			%do;
				(where=(_type_ = 1))
			%end;

		%if &numPDVars = 2 %then
			%do;
				(where=(_type_ = 3))
			%end;

		mean(p_&target.) = AvgYHat;
	run;

%mend PDFunction;

%macro ICEPlot(
			ICEVar=, samples=10, YHatVar=
			);
	/*Select a small number of individuals at random*/
	proc summary data = replicates;
		class obsID;
		output out=individuals (where=(_type_ = 1));
	run;

	data individuals;
		set individuals;
		random = ranuni(12345);
	run;

	proc sort data = individuals;
		by random;
	run;

	data sampledIndividuals;
		set individuals;

		if _N_ LE &samples.;
	run;

	proc sort data = sampledIndividuals;
		by obsID;
	run;

	proc sort data = replicates;
		by obsID;
	run;

	data ICEReplicates;
		merge replicates sampledIndividuals (in = s);
		by obsID;

		if s;
	run;

	/*Plot the ICE curves for the sampled individuals*/
	title "ICE Plot (&samples. Samples)";

	proc sgplot data = ICEReplicates;
		series x=&ICEVar. y = &yHatVar. / group=obsID;
	run;

%mend ICEPlot;

proc hpsplit data=sashelp.cars leafsize = 10;
	target MSRP / level = interval;
	input horsepower engineSize length cylinders weight MPG_highway MPG_city wheelbase / level = int;
	input make driveTrain type / level = nominal;
	code file="treeCode.sas";
run;

%PDFunction(dataset=sashelp.cars, target=MSRP, PDVars=horsepower, otherIntervalInputs=engineSize length cylinders weight MPG_highway MPG_city wheelbase, otherClassInputs=origin make driveTrain type, scorecodeFile=treeCode.sas, outPD=partialDependence );

proc sgplot data=partialDependence;
	series x = horsepower y = AvgYHat;
run;
quit;

%PDFunction(dataset=sashelp.cars, target=MSRP, PDVars=make, otherIntervalInputs=horsepower engineSize length cylinders weight MPG_highway MPG_city wheelbase, otherClassInputs=origin driveTrain type, scorecodeFile=treeCode.sas, outPD=partialDependence);

proc sgplot data=partialDependence;
	vbar make / response = AvgYHat categoryorder = respdesc;
run;

quit;

%PDFunction(
	dataset=sashelp.cars, target=MSRP, PDVars=horsepower origin,
	otherIntervalInputs=engineSize length cylinders weight MPG_highway MPG_city wheelbase, 
	otherClassInputs=make driveTrain type, scorecodeFile=treeCode.sas, outPD=partialDependence
	);

proc sgplot data=partialDependence;
	series x = horsepower y = AvgYHat / group = origin;
run;

quit;

%PDFunction(
	dataset=sashelp.cars, target=MSRP, PDVars= horsepower MPG_City, otherIntervalInputs= engineSize cylinders MPG_highway wheelbase length weight, otherClassInputs= make origin type driveTrain, scorecodeFile=treeCode.sas, outPD=partialDependence
	);

proc sgplot data=partialDependence;
	scatter x = horsepower y = MPG_City / colorresponse = avgYHat colormodel=(blue green orange red) markerattrs=(symbol=CircleFilled size=10);
run;

quit;

%ICEPlot( ICEVar=horsepower, samples=10, YHatVar=p_MSRP );