cas mySession;
caslib _all_ assign;

proc casutil;
	droptable incaslib="public" casdata="iris" quiet;
	load data=sashelp.iris outcaslib="public" casout="iris" promote;
	save casdata="iris" incaslib="public" outcaslib="public" replace;
run;
quit;

/*
	Ich arbeite mit der autotune-Funktion, einziger Eingriff:
	ich erlaube 3 Zweige je Knoten + Tiefe der Unterbaum-Plots erhöht.
	Ich wundere mich sehr, warum die Ergebnisse so wenig robust sind und so stark variieren,
	hier 2 Ergebnisse (2 zufällig ausgewählte Durchgänge gespeichert, NICHT die extremsten)
*/

proc treesplit data=public.iris maxbranch=3 plots(only)=(wholetree zoomedtree(depth=5) );
	input SepalLength SepalWidth PetalLength PetalWidth / level=interval;
	target Species / level=nominal;
	prune none;
	autotune tuningparameters=(maxdepth numbin criterion) objective=misc fraction=0.3;
run;

proc treesplit data=public.iris maxbranch=3 plots(only)=(wholetree zoomedtree(depth=5) );
	input SepalLength SepalWidth PetalLength PetalWidth / level=interval;
	target Species / level=nominal;
	prune none;
	autotune tuningparameters=(maxdepth numbin criterion) objective=misc kfold=5 maxiter=100 maxevals=100000 popsize=100;
run;

/*
	Außerdem interessiert mich die Wahl der Entscheidungsgrenzen.
	Ich habe mir dazu einen Datensatz mit 10.000.0000 Zeilen und 2 Spalten (Art; x) erzeugt: 
	5.000.000 Zeilen haben die Ausprägungen art=A und x=2 und 5.000.000 Zeilen haben die Art=B und x=10.
	SAS wählt hier als Entscheidungsgrenze 2.4. Warum?
*/
data casuser.Tree_Test_Simulated;
	length art $1;
	length x 3;
	do i=1 to 10000000;
		if i <= 5000000 then
			do;
				art='a';
				x=2;
			end;
		else do;
				art='b';
				x=10;
		end;
		output;
	end;
run;

proc treesplit data=casuser.Tree_Test_Simulated plots(only)=(wholetree zoomedtree(depth=5) );
	input x / level=interval; /* Eigentlich nimmt man hier nominal. */ 
	target art / level=nominal;
	prune none;
	partition fraction(test=0.1 validate=0.3);
run;

/* Hier ein Überblick über die erhaltenen Variablengewichtigkeiten */

proc forest data=public.iris; 
	target Species / level=nominal; 
	input SepalLength SepalWidth PetalLength PetalWidth / level=interval; 
	autotune tuningparameters=(ntrees maxdepth inbagfraction vars_to_try(init=4) ) fraction=0.3; 
run; 

proc forest data=public.iris; 
	target Species / level=nominal; 
	input SepalLength SepalWidth PetalLength PetalWidth / level=interval; 
	crossvalidation kfold=5;
run; 

/* Hier ein Überblick über die erhaltenen Variablengewichtigkeiten */

proc gradboost data=public.iris;
	target Species / level=nominal;
	input SepalLength SepalWidth PetalLength PetalWidth / level=interval;
	autotune tuningparameters=(ntrees samplingrate vars_to_try(init=4) learningrate lasso ridge) objective=misc fraction=0.3;
run;

proc logselect data=public.iris;
   class Species;
   model Species=SepalLength SepalWidth PetalLength PetalWidth;
run;



cas terminate mySession;