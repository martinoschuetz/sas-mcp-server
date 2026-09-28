proc hpfdiagnose data=sashelp.air outoutlier=outliers;
	id date interval=quarter accumulate=total;
	forecast air;
	arimax outlier=(detect=yes maxnum=10 maxpct=50 SIGLEVEL=0.05);
/*	by id;*/
run;

proc sql;
	create table max_outlier
		as select id, 
			max(_estimate_) as max_outlier format = 8.1,
			sum(_estimate_ > 5) as CNT_Outlier_GT5 
		from outliers
			group by id;
quit;

%macro outlier_plot(limit);
	filename reflines 'C:\POC\Programme\tmp\reflines_outliers.sas';

	data outlier_select;
		set outliers;
		where _estimate_ > &limit and year(_sasdate_) ne 2011;
	run;

	/***  zur Beschreibung des Outputs ***/
	proc sql noprint;
		select count(distinct id) into :cnt_zempf from outlier_select;
		select distinct id into :zempf_list separated by " " from  outlier_select;
	quit;

	proc sql;
		select "Es wurden ", count(distinct id), "ids mit Outlier und einem Shift oder Peak von größer 5 Schäden gefunden"
			from  outlier_select;
	quit;

	%do i = 1 %to &cnt_zempf;
		%let id = %scan(&zempf_list,&i);

		data _NULL_;
			set outliers(where =(id in ("&id")));
			file reflines;
			format label $20.;
			label = "";

			if _TYPE_ = 'AO' then
				label=cats(label,'Outl',"_");
			else if _TYPE_ = 'LS' then
				label = cats(label,'Shft',"_");

			if _direction_ = 'UP' then
				label = cats(label,'Up');
			else if _direction_ = 'DOWN' then
				label = cats(label,'Dwn');
			label=cats(label,"_",put(abs(round(_estimate_)),3.));
			label=cats(label,"_",put(_sasdate_,yymmp7.));
			put @04 "refline '" _sasdate_ "'d / axis = x label = '" label "';";
		run;

		proc sgplot data=abt_time_min10;
			by id;
			where id in ("&id");
			series x=mon_amdatmd y=AnzSchaden;

			%include reflines;
			footnote Created with the SAS Fraud Solution 2017-04-04;
		run;

	%end;

	footnote;
%mend;

%outlier_plot(5);