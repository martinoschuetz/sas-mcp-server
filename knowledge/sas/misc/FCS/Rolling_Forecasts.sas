libname a "D:\DATEN\XXX";
options nosymbolgen;

%macro rollingforecast;
	libname fcslib "D:\DATEN\FORECAST";

	%do index=1 %to 14;

		data fcslib.inpudatdata;
			set a.inputdata&index;
		run;

		%include "D:\Daten\FSProjects\Projects\XXXX\DIAGNOSE_PROJECT_IMPORT_DATA.sas" /LRECL=512;
		libname _HPF0 "D:\Daten\FSProjects\Projects\YYY\hierarchy\ARTIKEL";
		libname datalib "D:\Daten\FSProjects\Projects\YYY";
		libname a "D:\DATEN\YYY";

		data a.outfor&index;
			set _HPF0.outfor;
			PREDICT&index=int(PREDICT);
			UPPER&index=int(UPPER);

			if LOWER&index>0 then
				LOWER=int(LOWER);
			else LOWER=0;
			keep ARTIKEL MONAT PREDICT&index;
		run;

		data a.data&index;
			set datalib.data;
		run;

		data a.outstat&index;
			set _HPF0.outstat;
			mape&index=mape;
			mdape&index=mdape;
			rmse&index=rmse;
			format mape&index rmse&index mdape&index 8.4;
			keep artikel rmse&index mape&index mdape&index;
		run;

		data a.outest&index;
			set _HPF0.outest;
		run;

		data a.outest&index;
			set _HPF0.outest;

			if not first.artikel then
				delete;
			by artikel;
			modell&index=_LABEL_;
			component&index=_COMPONENT_;
			parameter&index=_EST_;
			keep artikel modell&index component&index parameter&index;
		run;

	%end;
%mend;

%rollingforecast;

data a.modelluebersicht;
	merge a.outest1 a.outest2 a.outest3 a.outest4 a.outest5 a.outest6 
		a.outest7 a.outest8 a.outest9 a.outest10 a.outest11 a.outest12 a.outest13 a.outest14;
	by artikel;
run;

data a.prognosen;
	merge a.outfor1 a.outfor2 a.outfor3 a.outfor4 a.outfor5 a.outfor6 
		a.outfor7 a.outfor8 a.outfor9 a.outfor10 a.outfor11 a.outfor12 a.outfor13 a.outfor14;
	by artikel monat;
run;

data a.statistiken;
	merge a.outstat1 a.outstat2 a.outstat3 a.outstat4 a.outstat5 a.outstat6 
		a.outstat7 a.outstat8 a.outstat9 a.outstat10 a.outstat11 a.outstat12 a.outstat13 a.outstat14;
	by artikel;
run;

proc export data=a.modelluebersicht replace
	dbms=excel2000
	outfile='D:\DATEN\YYY\YYY_PROGNOSEN_v2.xls';
	sheet=Modelle;
run;

proc export data=a.statistiken replace
	dbms=excel2000
	outfile='D:\DATEN\YYY\YYY_PROGNOSEN_v2.xls';
	sheet=Statistiken;
run;

proc export data=a.prognosen replace
	dbms=excel2000
	outfile='D:\DATEN\YYYY\YYY_PROGNOSEN_v2.xls';
	sheet=Prognosen;
run;

%put ("Fertig");