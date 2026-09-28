/*
	Ich konvertiere Dateien auf diesem Weg:

	libname in cvp "...pfad1";
	libname out "..pfad2" outencoding="utf-8";

	data out.ziel;
		set in.quelle;
	run;

	Wenn kryptische Zeichen drin sind,
	konvertiert dieses Programm alle unlesbaren Zeichen in "?"
	damit kann die Datei dann zumindest ganz gelesen/geladen werden
*/
%macro sas_iconv_dataset(in,out,from=UNDEFINED,to=UNDEFINED,sub='?',file_opt=);

	data &out(encoding=asciiany);
		set &in;
		array cc (*) _character_;

		do _N_=1 to dim(cc);
			cc(_N_)=kpropdata(cc(_N_),&sub,"&from","&to");
		end;
	run;

	%let lib=%scan(&out,1,%str(.));
	%let mem=%scan(&out,2,%str(.));

	%if %length(&mem) = 0 %then
		%do;
			%let mem=&lib;
			%let lib=work;
		%end;

	proc datasets lib=&lib nolist;
		modify &mem / correctencoding="&to";
	run;

	quit;

%mend;

libname tmp '/data/demo63/demogroup1/testdata';

%sas_iconv_dataset(tmp.WAHLSTATISTIK_BUNDESLAENDER,tmp.WAHLSTATISTIK_BUNDESLAENDER,from=utf-8,to=utf-8);