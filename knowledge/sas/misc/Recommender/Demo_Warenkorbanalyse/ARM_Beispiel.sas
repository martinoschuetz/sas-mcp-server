libname mydata "c:\Olli\Demos\VA_local";
/* Makro-Variablen zur Parametrisierung der Abfrage */
%let level=Untergruppe;
%let support_low=50;
%let support_high=5000;
%let conf_low=0.05;


/* LASR Server Starten */
libname lasr1 sasiola startserver=(path="c:\temp" keeplog=yes maxlogsize=20) 
tag='hps' host="gerosr-2" port=55555;




/*--- load the data into memory ----------------------------*/

data lasr1.assoc_input;
	set mydata.bondaten_baumarkt_V2(keep=trans_id &level.);
run;

proc imstat;
	/*--- Explore the data set ---*/
	tableinfo / port=55555;
	table lasr1.assoc_input;
	columninfo;
	run;
quit;

proc imstat;
    table lasr1.assoc_input;
	/* Durchlauf der Assoziationsregel-Aufdeckung */
	 arm item=&level. tran=TRANS_ID / 
           itemsTbl maxItems = 2 support(lower =&support_low. upper=&support_high.)
		   rules(confidence(LOWER=&conf_low.)) rulesTbl;
	run;
	
    table lasr1.&_tempARMItems_;
	  promote itemstable;
    run;

	table lasr1.&_tempARMRules_;
	  promote rulestable;
	  purgetemptables;
	run;

	table lasr1.itemstable;
	where _SETSIZE_>=2;
	fetch / orderby=( _COUNT_ _Support_) desc=_COUNT_ from=1 to=20;
	run;

	table lasr1.rulestable;
	where _SETSIZE_>=2;
	fetch / orderby=(_Confidence_ _SetCount_) desc=_Confidence_ from=1 to=20;
    run; 

quit;


/* Export in lokale SAS Tabelle */
%macro out(in=,out=);
proc hpds2 data=&in. out=&out.;
	data DS2GTF.out;
		method run();
			set DS2GTF.in;
		end;
	enddata;
run;
%mend;

%out(in=lasr1.rulestable,out=mydata.rulestable);


/* Server herunterfahren */
proc delete data=lasr1.assoc_input; run;
libname lasr1 clear;

