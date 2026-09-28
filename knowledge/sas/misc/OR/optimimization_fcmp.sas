/**
@file
@brief <Your brief here>
<h4> SAS Macros </h4>
**/
%let suffix = _stoer10;

/*---------------------------------------------------------------------------*/
/*          1. COLUMN K01                      */
/*---------------------------------------------------------------------------*/
%let vars01 = timestamp k1_apc_status lc80170_mode _partInd_ fc80112 fc80131 fc80147 fq80949 fr80170 fr80171 fr80949 fr89112 tc80112_stoer;
%let vars_num01 = fc80131 fc80147 fq80949 fr80170 fr80171 fr80949 fr89112 tc80112_stoer;
%let vars_num_cas01 = "fc80131", "fc80147", "fq80949", "fr80170", "fr80171", "fr80949", "fr89112", "tc80112_stoer";
%let vars_num_sql01 = fc80131, fc80147, fq80949, fr80170, fr80171, fr80949, fr89112, tc80112_stoer;
%let vars_cat01 = lc80170_mode;
%let vars_cat_cas01 = "lc80170_mode";
%let vars_cat_sql01 = lc80170_mode;
%let target01 = fc80112;

data work.subset;
	id = _n_;
	set stg.abt (keep=&vars01. where=(_partInd_ in (1, 2)));
run;

/*---------------------------------------------------------------------------*/
/*          2. CUSTOM FUNCTIONS                    */
/*---------------------------------------------------------------------------*/
/* proc fcmp outlib=work.score.funcs; */
/*    function astore_k1_steam(&vars_num_sql01.); */
/*       declare object myscore(astore); */
/*       call myscore.score("/mnt/viya-share/data/sbxsva/_Y7QYHSPQ9Q8E1MUZ1JH8AS7FH.sasast"); */
/*       return(P_fc80112); */
/*    endsub; */
/* run; */
/* quit; */
proc fcmp outlib=work.score.funcs;
	function score_k1_steam(&vars_num_sql01., &vars_cat_sql01);

		*%fixsettings;
		%include '/mnt/viya-share/data/sbxsva/ScoreCode964609778.sas';
		return (p_fc80112);
	endsub;
run;

quit;

/*---------------------------------------------------------------------------*/
/*          4. OPTIMIZATION                      */
/*---------------------------------------------------------------------------*/
options cmplib=work.score;

/*Get fixed values 5033*/
%macro optimize(start=1, end=5033);
	%do id = &start. %to &end.;
		%do i = 1 %to %sysfunc(countw(&vars_num01. &vars_cat01., ' '));
			%put &i.;

			proc sql noprint;
				select %scan(&vars_num01. &vars_cat01., &i.) into :%scan(&vars_num01. &vars_cat01., &i.)
					from work.subset
						where id = &id.;
			quit;

		%end;

		proc optmodel;
			var fr80949 >= 0;
			var fr80170 >= 0;
			var fr80171 >= 0;
			var fc80147 >= 0;
			var fc80131 >= 0;
			var tc80112_Stoer <= 0;
			var fq80949 >= 0;
			var fr89112 >= 0;
			var lc80170_mode binary;
			impvar fc80112 = score_k1_steam(&vars_num_sql01., &vars_cat_sql01.);
			con fc80112_lb: fc80112 >= 0;
			con fr80170_ub: fr80170 >= 10;
			con fr80170_lb: fr80170 <= 23;
			con lc80170_mode_fix: lc80170_mode=&lc80170_mode.;
			con fr80170_fix: fr80170=&fr80170.;
			con fr80171_fix: fr80171=&fr80171.;
			con fr80949_fix: fr80949=&fr80949.;
			con fr89112_fix: fr89112=&fr89112.;
			con tc80112_Stoer_fix: tc80112_Stoer = -10;
			con fc80147_fix: fc80147 = &fc80147.;
			con fc80131_fix: fc80131 = &fc80131.;
			con fq80949_fix: fq80949 = &fq80949.;
			min TotalSteam = sum(fc80112);
			solve with blackbox;
			create data work.tmp from &vars_num01. fc80112 TotalSteam;
		quit;

		data work.tmp;
			set work.tmp;
			id = &id.;
		run;

		%if &id. = 1 %then
			%do;

				data stg.optimization_out&suffix.;
					set work.tmp;
				run;

			%end;
		%else
			%do;

				proc append base=stg.optimization_out&suffix. data=work.tmp;
				run;

			%end;
	%end;
%mend optimize;

%optimize;

proc sql;
	create table stg.optimization_out2&suffix. as
		select t1.*
			, t2.fc80112 as fc80112_orig
			, t2.fr80170 as fr80170_orig
			, t2.fr80171 as fr80171_orig
			, t2.timestamp
			, t2.k1_apc_status
			, t2.lc80170_mode
			, t2._partInd_
		from stg.optimization_out&suffix. t1
			inner join work.subset t2 on t1.id = t2.id;
quit;

proc casutil incaslib="public" outcaslib="public";
	droptable casdata="optimization_out2&suffix." quiet;
quit;

data public.optimization_out2&suffix. (promote=yes);
	set stg.optimization_out2&suffix.;
run;