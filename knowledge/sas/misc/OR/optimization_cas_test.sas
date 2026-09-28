/* Globally available variables for optimization */
%global n_vars vars;
%let n_vars=3;
%let vars=EngineSize Horsepower MPG_Highway;


/* Build Astore model */
data casuser.cars;
	set sashelp.cars;
run;

proc casutil;
	droptable incaslib="public" casdata="cars_ast" quiet;
quit;
proc gradboost data=casuser.cars noprint;
	id MSRP;
	crossvalidation kfold=5;
	input EngineSize Horsepower MPG_Highway / level=interval;
	target MSRP / level=interval;
	savestate rstore=public.cars_ast;
run;
proc casutil;
	promote incaslib="public" casdata="cars_ast" outcaslib="public" casout="cars_ast";
quit;

/* 	Start Optmodel formulation */
/* 	The ASTORE scoring requires the actual value of the objective function. 
	It will be routed to the scoring as fixed parameter. */
data casuser.problem_formulation;
	format name $15.;
	input name $ lower initial upper;
	datalines;
EngineSize 1.0 2.8 8.5
Horsepower 70.0 150.0 550.0
MPG_Highway 10.0 25.0 70.0
MSRP 15000 15000 15000
;

data data casuser.fixed;
	format name $15.;
	input name $;
	datalines;
MPG_Highway
MSRP
;

/* Generate fitness function evaluation code outside proc cas to have access to all macro variables. */
%macro score_code;
	%local i;

	data public.prodIn;
		%do i=1 %to &n_vars.;
			%let var=%scan(%bquote(&vars.), &i.);
			%put &=i. &=var.;
			&var.=%nrquote("||x["&var."]||");
		%end;
		MSRP=10000.0;
	run;

%mend score_code;

proc cas noqueue;
	source pgm;
	set <str> NAMES;
	num lower{NAMES};
	num initial{NAMES};
	num upper{NAMES};
	read data casuser.problem_formulation into NAMES=[name] lower initial upper;
	set <str> FiXED;
	read data casuser.fixed into FiXED=[name];
	/*	The setpoints definition is not necessary */
/*	set <str> SETPOINTS=NAMES diff FIXED; */

	put NAMES;
	print lower initial upper;
	put FIXED;
/*	put SETPOINTS;*/

	var x{i in NAMES} init initial[i] >=lower[i] <=upper[i];
	for {i in FIXED} fix x[i]=initial[i];

	string evalCode;
	source evalCode end=endsrc;

		/* Generate state vector using CASL */
		datastepcode = "data public.prodIn;";
		do name,val over x;
			datastepcode = datastepcode||name||"="||val||";";
		end;
/*		datastepcode = datastepcode||"MSRP=10000.0;";*/
		datastepcode = datastepcode||"run;";
		
		datastep.runcode/single="yes" code=datastepcode;
				
		/* 	An alternative solution is to call the macro  in the above code statement
			The macro generates the following data step.

			datastep.runcode/single="yes" code="
				%score_code;
			";
			data casuser.prodIn;
				EngineSize="||x['EngineSize']||";
				Horsepower="||x['Horsepower']||";
				MPG_Highway=30.0;
				MSRP=10000.0;
			run;
		*/

		/* Score state vector to get model response / fitness value */	
			astore.score result=r status=rc/ 
				table={caslib="public", name="prodIn"} 
				rstore={caslib="public", name="cars_ast"} 
				out={caslib="casuser", name="prodIn_scored", replace=true}; run;

			table.dropTable / caslib="public" name="prodIn" quiet=TRUE; run;
			
			table.fetch result=r / table={caslib="casuser", name="prodIn_scored"}; run;
			
			f["P_MSRP"]=r["Fetch"][1][2];

			send_response(f);

	endsrc;
	
	expand;

	min Target_Global=caslevaln(evalCode, "P_MSRP", x);

	solve with blackBox/ popsize=100 maxgen=20;

	create data casuser.Optimal_Setpoints from
	[VariableName]=NAMES Optimal_Value=x LowerBound=lower UpperBound=upper;
	
	create data casuser.Objective from Target_Global=Target_Global;
	endsource;

	optimization.runOptmodel/code=pgm; run;

	table.dropTable / caslib="public" name="Opt_Output" quiet=TRUE; run;

	datastep.runcode/single='yes' code="

		data casuser.Opt_Output;
			set casuser.Optimal_Setpoints casuser.Objective;
		run;";
	
	table.promote/ caslib="casuser" name="Opt_Output" target="Opt_Output" targetLib="public";
/*	table.save/ caslib="public" table={name="Opt_Output", caslib="public"} name="Opt_Output" replace=True;*/
	
quit;