libname data "D:\Codes";

data vardata;
	input _id_ $ _lb_ _ub_;
	datalines;
x1 0 5
x2 0 5
;

proc fcmp outlib=data.myfuncs.mypkg;
	function fdef1(x1, x2);
		return ((x1-1)**2 + (x1-x2)**2);
	endsub;

	function fdef2(x1, x2);
		return ((x1-x2)**2 + (x2-3)**2);
	endsub;
run;

data objdata;
	input _id_ $ _function_ $ _sense_ $;
	datalines;
f1 fdef1 min
f2 fdef2 min
;

options cmplib = data.myfuncs;

proc optlso
	primalout = solution
	variables = vardata
	objective = objdata
	logfreq = 50
;
run;

proc transpose data=solution out=pareto label=_sol_ name=_sol_;
	by _sol_;
	var _value_;
	id _id_;
run;

proc gplot data=pareto;
	plot f2*f1;
run;

quit;