libname TMP 'C:\Projekte\Demo\ESTG\DATA\TMP';

proc tgparse
	data=TMP.TMFILTER2
	language='German'
	entities=yes
	stemming=yes
	tagging=yes
	ng=max
	key=tmp.key1
	out=tmp.out1 addterm addtag addparent addoffset;
	var text;
run;

* Zweites Parsen zumr Berücksichtigung der Schreibweisekorrktur und Stopliste und Rollenselektion;
proc tgparse
	data=TMP.TMFILTER2
	stop=sashelp.grmnstop /* ignore= */
	language='German'
		syn=tmp.tmspell
		entities=yes
		stemming=yes
		tagging=yes
		ng=max
		key=tmp.key2
		out=tmp.out2 addterm addtag addparent addoffset;
	select 	"Num" "Punct" "Prep" "Pron" "verbadj" "det" "conj"
		"location" "measure" /drop;
	var text;
run;

data stop;
	set key(where=(keep eq 'N'));
run;