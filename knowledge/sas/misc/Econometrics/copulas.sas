/* Keep only the last 250 observations of the data */
data returns;
	set sashelp.citiday;/* nobs=observ;

	if (_N_ > observ-250);*/
run;

proc contents data=work.returns(drop=date) out=outcontent; run;
proc sql;
select name into :vars separated by ' ' from outcontent; 
quit;
%put &=vars.;

ods graphics on;
*ods output FitSummary=FitSummary_NORMAL;
/* Normal copula estimation */
proc copula data = returns;
	ods output ConvergenceStatus=ConvergenceStatus_NORMAL;
	var  &vars.;
	fit NORMAL / itprint printall outcopula=estimates_NORMAL;
run;
ods graphics off;

/* Student T copula estimation */
proc copula data = returns;
	var  &vars.;
	fit T / outcopula=estimates_T;
run;

/* Clayton copula estimation */
proc copula data = returns;
	var  &vars.;
	fit CLAYTON / outcopula=estimates_CLAYTON;
run;

/* Clayton copula estimation */
proc copula data = returns;
	var  &vars.;
	fit GUMBEL / outcopula=estimates_GUMBEL;
run;

/* Clayton copula estimation */
proc copula data = returns;
	var  &vars.;
	fit FRANK / outcopula=estimates_FRANK;
run;

/* keep only correlation estimates */
data estimates;
	set estimates(keep=&vars);
run;

/* Copula simulation of uniforms */
proc copula;
	var &vars;
	define cop normal (corr = estimates);
	simulate cop / ndraws = 500
		seed = 1234
		outuniform = simulated_uniforms
		plots=(datatype=uniform);
run;

/* Copula estimation and simulation of returns */
proc copula data = returns(drop=date);
	var &vars.;

	* fit T-copula to stock returns;
	fit T /
		marginals = empirical
		method = MLE
		plots = (datatype = both)
		outcopula=outcopula;

	* simulate 10000 observations;
	* independent in time, dependent in cross-section;
	simulate /
		ndraws = 10000
		seed = 1234
		out = simulated_returns
		plots(unpack) = (datatype = original);
run;

proc hpcorr data=returns(drop=date) out=inparm(where=(_TYPE_ eq "CORR")); run;
data inparm;
	set inparm(drop=_TYPE_);
run;

/* simulate the data from bivariate normal copula */
proc hpcopula;
	var &vars.;
	define cop T /* (corr=inparm)*/
		;
	PERFORMANCE details;
run;

proc hpcopula;
	var &vars.;
	define cop T /* (corr=inparm)*/;
	simulate cop /
		ndraws = 1000000
		seed = 1234
		outuniform = normal_unifdata;
		PERFORMANCE details;
run;

