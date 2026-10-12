/* Redefine a few macros with minor modifications to work with svdd vs stability monitoring */

%macro anl_getstab_attributes(analysisID,analysisnm,keygroup) ;
%put NOTE: *** anl_getstab_attributes is being overriden ***;

/* Globalize the analysisID */
   %global g_analysisID g_solutionCD g_instance_nm g_applib sysusername G_WRNAOUT G_TEMPREPORTVARPROD G_DATA_DOMAINS ;
   %let g_analysisID=&analysisID;
   %let g_applib=mfgapp;
	%let G_WRNAOUT= work;
	
	proc sql noprint nowarn nowarnrecurs;
	create table table_meta as select * from &g_applib..table_meta;
	create table tablecolumn_meta as select 
	column_id,column_data_type_cd as column_data_type,column_desc,column_fmt_nm,column_label_txt as column_label,column_nm,table_id
	from &g_applib..tablecolumn_meta;
	create table table_attributes as
	select 		table_attr_id,		created_by_nm,		creation_dttm,		modified_by_nm,		modified_dttm,		attribute_data_type_cd,
	attribute_nm,		trim(left(attribute_val)) as attribute_value length=1000 ,		table_id 
	from  &g_applib..table_attributes;
	create table tablecolumn_attributes as
	select 		
	a.tablecolumn_attr_id,a.created_by_nm,a.creation_dttm,a.modified_by_nm,a.modified_dttm,a.attribute_data_type_cd,
	a.attribute_nm,trim(left(a.attribute_val)) as attribute_value length=1000,a.column_id,b.table_id 
	from &g_applib..tablecolumn_attributes a , &g_applib..tablecolumn_meta b
	where a.column_id = b.column_id;
	proc sort data=table_attributes out=table_attributes1;    by table_id; run;
	proc transpose data=table_attributes1 out=tableinfo;     by table_id;    id attribute_nm ;    var attribute_value ;    run;
	proc sort data=tablecolumn_attributes out=tablecolumn_attributes_1;
	by column_id; run;
	proc transpose data=tablecolumn_attributes_1 out=columninfo;
	by column_id;
	id attribute_nm ;
	var attribute_value ;
	run;
	proc sql noprint nowarn nowarnrecurs;
	create table columninfo as
	select a.* , b.column_nm , d.table_nm , c.*
	from columninfo a, tablecolumn_meta b , tableinfo c , table_meta d
	where a.column_id = b.column_id and b.table_id=c.table_id and c.table_id=d.table_id
	;
	quit;
	data data_sel_transpose;
	length transpose_attribute_nm transpose_attribute_value data_sel_id $10.;
	transpose_attribute_nm="";
	transpose_attribute_value="";
	data_sel_id="";
	run;
	
	proc sql noprint;
			select analysis_ins_id into :ins_id from mfgapp.analysis_ins_step where analysis_ins_step_id="&g_analysisID";
	quit;
	%let ins_id=%sysfunc(compress(&ins_id));
	data _null_; 
	 length method $6 digest $128; 
	 do method='CRC32'; 
	 digest = hashing(method,"&ins_id"); 
	 call symput('hash_ins_id' , digest );
	 end;
	 run;
	%let sysusername=;
	   
	proc sql noprint nowarn nowarnrecurs;
	create table analysis_instance as 
	select analysis_ins_step_id as instance_id , modified_by_nm,
	"&hash_ins_id" as instance_nm ,
	data_selection_id ,
	step_template_id as template_id ,scan(analysis_model_nm,1,"_") as analysis_type_cd,
	scan(step_nm,1,"_") as analysis_step_cd
	from mfgapp.analysis_ins_step a , mfgapp.analysis_ins b
	where a.analysis_ins_step_id="&g_analysisID" and a.analysis_ins_id=b.analysis_ins_id
	;
	quit;
	
	proc sql noprint nowarn nowarnrecurs;
	create table analysis_ins_step_input as select * from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&g_analysisID";
	quit;
	proc sql noprint nowarn nowarnrecurs;
	select distinct analysis_ins_step_id into :l_anlstepid from analysis_ins_step_input;
	quit;
	
	
%macro VarExistCreate(ds, var);
%local rc dsid result resx;
%let dsid = %sysfunc(open(&ds));
%let resx = %sysfunc(varnum(&dsid, &var));
%let rc = %sysfunc(close(&dsid));
%if &resx > 0 %then %do;
%let result = 1;
%put NOTE: Var &var exists in &ds;
%end;
%else %do;
%let result = 0;
%put NOTE: Var &var not exists in &ds;
data &ds;
&var="";
set &ds;
run;
%end;
%mend VarExistCreate;
	%let xvar_sensor=;
	%let yvar_sensor=;
	%let byvars_sensor1=;
	%let idvar_sensor=;
	%let xvar_event=;
	%let byvars_event1=;
	%let idvar_event=;
	%let yvar_event=;
	%let batch_var=;
	%let item_var=;
	
	
	
		data analysis_ins_step_input_All;
		set analysis_ins_step_input;
		run;
		
		proc sql noprint nowarn nowarnrecurs;
		create table data_sel_id as select data_selection_id,analysis_ins_step_id from
		mfgapp.analysis_ins a, mfgapp.analysis_ins_step b 
		where b.analysis_ins_step_id = "&g_analysisId" and a.analysis_ins_id=b.analysis_ins_id ;
		quit;
	
		proc sql noprint nowarn nowarnrecurs;
			select distinct data_selection_id into :l_inst_id from data_sel_id;
			data ds_instance_param;
			length instance_id $100.;
			length param_value_txt $100.;
			length domain $100.;
			length transpose $100.;			
			length param_cd $100.;
			run;
		%if &keygroup eq ASSET %then %do;
			proc sql noprint nowarn nowarnrecurs;
			insert into ds_instance_param (instance_id,param_value_txt,domain,transpose,param_cd)
			values ("&l_inst_id","","TAGS","Y","LAUNCHVARS")
			values ("&l_inst_id","","EVENTS","Y","LAUNCHVARS");	
			quit;
		%end;
		
		proc sql noprint nowarn nowarnrecurs;
			delete * from ds_instance_param where instance_id = "";
		quit;
		
	
	proc sql noprint nowarn nowarnrecurs;
	select distinct data_selection_id into :l_data_id from data_sel_id;
	select distinct analysis_ins_step_id into :l_analysis_ins_step_id from data_sel_id;
	quit;
	
	proc sql noprint nowarn nowarnrecurs;
	create table analysis_instance_param as
	select 
	analysis_ins_step_id as instance_id,
	analysis_param_nm as param_cd,
	case when 
		upcase(analysis_param_nm) in ("REPORTVAR","GROUPVAR","BYVAR","ANALYSISVAR","XVAR_SENSOR","YVAR_SENSOR","BYVARS_SENSOR","XVAR_EVENT","BYVARS_EVENT","IDVAR_SENSOR","IDVAR_EVENT","BATCH_VAR","ITEM_VAR") then 
			scan(param_value_txt,2,":.") else param_value_txt 
		end as param_value_txt
	from analysis_ins_step_input_all
	where analysis_ins_step_id="&g_analysisID"
	;
	quit;
	
	
		
	
/* Query analysis and data selection information */
   %global g_analysisType g_dataSelectionID g_templateID g_modified_by_nm;
   data _null_;
     set Analysis_instance (where=(INSTANCE_ID = "&analysisID"));
     call symput('g_analysisType', strip(ANALYSIS_TYPE_CD));
     call symput('g_dataSelectionID', strip(DATA_SELECTION_ID));
     call symput('g_templateID', strip(TEMPLATE_ID));
	 call symput('g_modified_by_nm', strip(modified_by_nm));
	 call symput('g_instance_nm', strip(instance_nm));
	 
   run;
/* Assign stndard output datasets */
   %global g_prepOutputDS g_outputDS;
   %let g_prepOutputDS = work.&g_analysisType._s_Output;
%let g_OutputDS = &g_wrnaout..&g_analysisType._output;
/* Query the options selected by the USER   */
/* these will override the defaults (above) */
   %anl_makemacrovars( p_dataSet=Analysis_instance_param, 
                       p_whereClause=%quote(INSTANCE_ID="&analysisID"),
                       p_macroVar=PARAM_CD,
                       p_macroStmt=PARAM_VALUE_TXT,
                       p_macroPrefix=g_ ) ;  
/* For debugging */
   
      %put _global_;
      
      
		%if not %symexist(g_query_only_cas) %then %do;
		   %global g_query_only_cas;
		   %let g_query_only_cas=Y;
   		%end;
   
   		%if %symexist(g_query_only_cas_score) %then %do;
   			%let g_query_only_cas=&g_query_only_cas_score;
   		%end;
   
		data data_sel_transpose;
		length transpose_attribute_nm transpose_attribute_value data_sel_id $100.;
		transpose_attribute_nm="periodicity_interval_cd";transpose_attribute_value="&g_PERIODICITY_UNIT";data_sel_id="DS";output;
		transpose_attribute_nm="periodicity_no";transpose_attribute_value="&g_PERIODICITY";data_sel_id="DS";output;
		transpose_attribute_nm="aggregation_method_cd_TAGS";transpose_attribute_value="&g_AGGREGATION_METHOD";data_sel_id="DS";output;
		transpose_attribute_nm="aggregation_method_cd_Events";transpose_attribute_value="&g_AGGREGATION_METHOD";data_sel_id="DS";output;
		transpose_attribute_nm="query_only_cas";transpose_attribute_value="&g_query_only_cas";data_sel_id="DS";output;
		
		run;
		%global G_EVENT_ID_COLUMNVAR EVENT_DIMTABLE EVENT_IDVAR ;
%qas_getfiltereddata(g_data_ID=&l_data_id,g_analysisid=%nrbquote(&l_analysis_ins_step_id));
		%global g_pam_asset_id_var g_byvar g_reportvar;
		%let g_pam_asset_id_var=PAM_ASSET_ID;
	
		%GET_LAUNCHVALUES(g_launchdataname=ds_transpose);
		%include "&viewpath./DS_Values.txt";
		
		 %if &anl_type ne SCORING %then %do;
		
		proc fedsql sessref=mysession;
		create table DS_TAGS_LIST {options replace=true}as
		select distinct &g_tag_id_var , &g_pam_asset_id_var , &g_tag_id_columnvar
		from ds_tags;
		quit;

         %wrna_create_filteredvalues(tablename=DS_TAGS_LIST,listofcolumns= &g_tag_id_var &g_pam_asset_id_var,outdata=,orderbycols=);
		
		proc fedsql sessref=mysession;
		create table DS_ASSETS_LIST {options replace=true}as
		select distinct &g_pam_asset_id_var
		from ds_tags_list;
		quit;

		proc fedsql sessref=mysession;
		create table DS_EVENTS_LIST{options replace=true} as
		select distinct a.&g_event_id_var , a.&g_pam_asset_id_var ,&G_EVENT_ID_COLUMNVAR
		from ds_events a inner join &EVENT_DIMTABLE b on (a.&EVENT_IDVAR =b.&EVENT_IDVAR );
		quit;
		
		%wrna_create_filteredvalues(tablename=DS_EVENTS_LIST,listofcolumns= &g_event_id_var &g_pam_asset_id_var,outdata=,orderbycols=);
		
		proc cas;
		session mysession;
		datastep.runcode / code="
		data ds_tagscnt (keep=&g_tag_id_var &g_pam_asset_id_var &g_tag_id_columnvar dt hour);
		format dt date9.;
		set ds_tags ;
		dt=datepart(&g_tag_dt);
		hour=hour(&g_tag_dt);
		run; ";
		run;
		quit;
		
		proc fedsql sessref=mysession;
		create table ds_tagscnt{options replace=true} as
		select &g_tag_id_var ,&g_pam_asset_id_var,  dt, hour, count(*) as obscnt
		from ds_tagscnt
		group by &g_tag_id_var, &g_pam_asset_id_var,  dt, hour
		;
		quit;
		%wrna_create_filteredvalues(tablename=ds_tagscnt,listofcolumns= &g_tag_id_var &g_pam_asset_id_var,outdata=,orderbycols=);		
		proc cas;
				session mysession;
				datastep.runcode / code="
				data ds_eventscnt (keep=&g_event_id_var &g_pam_asset_id_var  dt hour);
				format dt date9.;
				set ds_events ;
				dt=datepart(&g_event_dt);
				hour=hour(&g_event_dt);
				run; ";
				run;
				quit;
				
		proc fedsql sessref=mysession;
		create table ds_eventscnt{options replace=true} as
		select &g_event_id_var ,&g_pam_asset_id_var,  dt, hour, count(*) as obscnt
		from ds_eventscnt
		group by &g_event_id_var, &g_pam_asset_id_var,  dt, hour
		;
		quit;
		
		%wrna_create_filteredvalues(tablename=ds_eventscnt,listofcolumns= &g_event_id_var &g_pam_asset_id_var,outdata=,orderbycols=);
		
		data varnames;
		length name value $1000.;;
		name="TAG_ID"; value="&g_tag_id_var"; output;
		name="TAG_ID_DEC"; value="&g_tag_id_var._DESC"; output;
		name="PAM_ASSET_ID";value="&g_pam_asset_id_var"; output;
		name="PAM_ASSET_DEC"; value="&g_pam_asset_id_var._DESC"; output;
		name="TAG_COLUMN_NM";value="&g_tag_id_columnvar"; output;
		name="EVENT_ID";value="&g_event_id_var"; output;
		name="EVENT_ID_DESC"; value="&g_event_id_var._DESC"; output;
		run;
		
		%if not %symexist(g_modifyaccess) %then %do;
		%global g_modifyaccess;
		%let g_modifyaccess=N;
		%end;
		%if not %symexist(g_casanlout) %then %do;
		%global g_casanlout;
		%let g_casanlout=QASANLOUT;
		%end;
		CAS myS SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );
		libname QASOUT CAS datalimit=all;
		data outputtables;
		length tablename $500.;
		run;
		
		%macro out(type=);
		data analysis_output;
		length instance_nm tablemask $500.;
		set analysis_instance;
		%if &type. eq %str() %then %do;
		instance_nm=strip(strip(analysis_type_cd)  || "_" || strip(instance_nm));
		%end;
		%else %do;
		instance_nm=strip(strip(analysis_type_cd) || "_" ||"&type."|| "_" || strip(instance_nm));
		%end;
		tablemask=tranwrd(instance_nm , "(","((");
		tablemask=tranwrd(tablemask , ")","))");
		tablemask=tranwrd(tablemask , "'","''");
		tablemask=tranwrd(tablemask ,'))','%str(%))');
		tablemask=tranwrd(tablemask ,'((','%str(%()');
		tablemask=tranwrd(tablemask , '"','%str(%")');
		run;
	
		proc sql noprint nowarn nowarnrecurs;
		select strip(tablemask) into :l_instance_nm from analysis_output;
		%let l_instance_nm=%trim(%left(&l_instance_nm));
		%if %symexist(l_ins_&type.) %then %do;
		%end;
		%else %do;
		 %global l_ins_&type.;
		%end; 
		%let l_ins_&type.=%trim(%left(&l_instance_nm));
	  %mend out;
		%if %nrbquote(&syserrortext) eq %then %do;
			%qas_output_promote_table(g_outputds=DS_Transpose,type=Transpose,desc=N,analysistype=&g_analysistype,from_lib=&G_CASLIB );
			%let g_reportvar=&g_event_id_var,&g_pam_asset_id_var;
			%qas_output_promote_table(g_outputds=DS_EVENTS_LIST,type=EVENTS,desc=Y,analysistype=&g_analysistype,from_lib=&G_CASLIB );
			%let g_reportvar=&g_tag_id_var,&g_pam_asset_id_var;
			%qas_output_promote_table(g_outputds=DS_TAGS_LIST,type=TAGS,desc=Y,analysistype=&g_analysistype,from_lib=&G_CASLIB );
			%qas_output_promote_table(g_outputds=DS_ASSETS_LIST,type=ASSETS,desc=Y,analysistype=&g_analysistype,from_lib=&G_CASLIB );
			%qas_output_promote_table(g_outputds=varnames,type=VARNAMES,desc=N,analysistype=&g_analysistype,from_lib=);
			
			%qas_output_promote_table(g_outputds=ds_tagscnt,type=TAGSCNT,desc=N,analysistype=&g_analysistype,from_lib=&G_CASLIB);
			
			%qas_output_promote_table(g_outputds=ds_eventscnt,type=EVENTSCNT,desc=N,analysistype=&g_analysistype,from_lib=&G_CASLIB);
			
			
			
			%out(type=tags);
			%out(type=assets);
			%out(type=transpose);
			%out(type=events);

			/* all vars must be caps */
			%let l_ins_TAGS = %sysfunc(upcase(&l_ins_TAGS));
			%let l_ins_ASSETS = %sysfunc(upcase(&l_ins_ASSETS));
			%let l_ins_TRANSPOSE = %sysfunc(upcase(&l_ins_TRANSPOSE));
			%let l_ins_EVENTS = %sysfunc(upcase(&l_ins_EVENTS));
			%let g_event_id_var = %sysfunc(upcase(&g_event_id_var));
			%let G_EVENT_ID_COLUMNVAR = %sysfunc(upcase(&G_EVENT_ID_COLUMNVAR));
			%let g_tag_id_columnvar = %sysfunc(upcase(&g_tag_id_columnvar));
			%let g_tag_id_var = %sysfunc(upcase(&g_tag_id_var));
			%let g_pam_asset_id_var = %sysfunc(upcase(&g_pam_asset_id_var));

			filename json_in temp;
			data _null_;
			file json_in;
			put '{ "analysisStepOutputParams": [ ';
			put ' { "outputname": "TARGET_VAR_TABLE" , "outputvalue" : "' "&l_ins_TAGS" '"} ,';
			put ' { "outputname": "ASSET_VAR_TABLE" , "outputvalue" : "' "&l_ins_ASSETS" '"} ,';
			put ' { "outputname": "TRANSPOSE_TABLE" , "outputvalue" : "' "&l_ins_TRANSPOSE" '"} ,';
			put ' { "outputname": "EVENT_VAR_TABLE" , "outputvalue" : "' "&l_ins_EVENTS" '"} ,';
			put ' { "outputname": "EVENT_VAR_KEY_COLUMN" , "outputvalue" : "' "&g_event_id_var" '"} ,';
			put ' { "outputname": "EVENT_VAR_VALUE_COLUMN" , "outputvalue" : "' "&g_event_id_var._DESC" '"} ,';
			put ' { "outputname": "EVENT_VAR_COLUMN_NAME" , "outputvalue" : "' "&G_EVENT_ID_COLUMNVAR" '"} ,';
			put ' { "outputname": "TARGET_VAR_COLUMN_NAME" , "outputvalue" : "' "&g_tag_id_columnvar" '"} ,';			
			put ' { "outputname": "TARGET_VAR_KEY_COLUMN" , "outputvalue" : "' "&g_tag_id_var" '"} ,';
			put ' { "outputname": "TARGET_VAR_VALUE_COLUMN" , "outputvalue" : "' "&g_tag_id_var._DESC" '"} ,';
			put ' { "outputname": "ASSET_VAR_KEY_COLUMN" , "outputvalue" : "' "&g_pam_asset_id_var" '"} , ';
			put ' { "outputname": "CASLIB" , "outputvalue" : "' "QASAnlOut" '"} , ';
			put ' { "outputname": "ASSET_VAR_VALUE_COLUMN" , "outputvalue" : "' "&g_pam_asset_id_var._DESC" '"}  ';
			put '  ] }';
			run;
					
		proc sql noprint nowarn nowarnrecurs;
		select analysis_ins_id into :ins_id from mfgapp.analysis_ins_step where analysis_ins_step_id="&analysisid";
		quit;
		%let ins_id=%sysfunc(compress(&ins_id));
		%let analysisid=%sysfunc(compress(&analysisid));
		%let m_service_template = %SYSGET(SAS_URL_SERVICE_TEMPLATE);
		%let BASE_URI_CREDENTIALS = %sysfunc(TRANWRD(&m_service_template.,@k8s.service.name@,sas-iot-analysis));
		/* reference that file as IN= parm in PROC HTTP POST */
		filename resp temp;
		proc http 
		 method="POST"
		url=
		"&BASE_URI_CREDENTIALS./iotAnalysis/analyses/&ins_id/steps/&analysisid/outputParams" OAUTH_BEARER = SAS_SERVICES
		ct="application/json"
		in=json_in
		out=resp; 
		 
		run;
		%end;
		%end; /** if anltype ne scoring **/
		%else %do; /** if anltype eq scoring **/
			%if not %symexist(g_modifyaccess) %then %do;
			%global g_modifyaccess;
			%let g_modifyaccess=N;
			%end;
			%if not %symexist(g_casanlout) %then %do;
			%global g_casanlout;
			%let g_casanlout=QASANLOUT;
			%end;
			CAS myS SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );
			libname QASOUT CAS datalimit=all;
			data outputtables;
			length tablename $500.;
			run;
			%if %nrbquote(&syserrortext) eq %then %do;
			%qas_output_promote_table(g_outputds=DS_Transpose,type=Transpose_Score,desc=N,analysistype=&g_analysistype,from_lib=&G_CASLIB );
			%end;
		%end;
		
%mend anl_getstab_attributes;

%macro wrna_getdscriteria_for_va ;

%let workpath=%sysfunc(pathname(WORK));

/* use the data selection critria gathered during the */
/* qas_getfiltereddata run to create a table of data  */
/* selection criteria                                 */

%let l_baselocale = %sysfunc(getoption(LOCALE));
proc sql nowarn ;

select count(*) into :l_dumyvarobs from mfgapp.filter_criteria where column_nm in ("RULEID","_CLUSTER_","BUILDTOSALEMONTHCOUNT","SALETOCLAIMMONTHCOUNT");

%if &l_dumyvarobs gt 0 %then %do;
	create table get_rowvars_all as
	select a.*,ui_display from get_rowvars_all a left join  mfgapp.filter_criteria b
	on a.column_nm=b.column_nm and a.child_level_num=b.child_level_num and a.childgroup_index=b.childgroup_index;

	delete * from get_rowvars_all where ui_display=0 and childgroup_index ne 0;

	create table dummy_rows as
	select operator_cd as dsfilter_operator_cd, column_nm,
	exclude_flg as dsfilter_exclude_flg ,
	value_txt as dsfilter_value_txt,
	childgroup_index as childgroup_index,
	child_level_num as child_level_num,2 as column_data_type
	from mfgapp.filter_criteria where ui_display=1 and compress(column_nm || put(childgroup_index,8.) || put(child_level_num,8.)) 
	not in (select compress(column_nm || put(childgroup_index,8.) || put(child_level_num,8.)) from get_rowvars_all) ;
	
	proc sql;
	create table datatypes1 as
	select distinct column_nm, column_data_type_cd, column_fmt_nm
	from mfgapp.tablecolumn_meta where column_nm in (select column_nm from mfgapp.filter_criteria);
	quit;

	proc sort data=datatypes1 nodupkey;
	by column_nm;
	run;
	
	proc sql noprint;
	create table dummy_rows as
	select coalesce(b.column_data_type_cd,2) as column_data_type , coalesce(b.column_fmt_nm,"") as column_fmt_nm,a.*
	from dummy_rows a 
	left join datatypes1 b on a.column_nm=b.column_nm 
	;
	quit;	

	proc append data=dummy_rows base=get_rowvars_all force; run;
	
	proc sort data=get_rowvars_all nodupkey;
	by column_nm child_level_num childgroup_index;
	run;

%end;

proc sql;

update get_rowvars_all set child_level_num=0 where child_level_num=.;
update get_rowvars_all set childgroup_index=0 where childgroup_index=.;
quit;

proc sql;
select distinct data_selection_id into :l_data_id from data_sel_id;
create  table get_rowvars_all1 as
select a.*,orig_data_sel_id
from get_rowvars_all a left join dist_data_sel_id b
on compress(a.group_id)=compress(b.group_id);
quit;

data finalcriteria;

length parent_ord_no 3.;
length concat_column $1000.;
   set get_rowvars_all(obs=0);
   keep concat_column column_nm dsfilter_operator_cd dsfilter_value_txt dsfilter_exclude_flg child_level_num childgroup_index chain_no column_fmt_nm column_data_type parent_ord_no;
  
run;
%global level;
%let level=1;
%let indent_char=;
%global hier_level;
%let hier_level=0;
%macro get_listofids(data_sel_id=);
	%let hier_level=%eval(&hier_level+1);

              %let data_sel_id = %sysfunc(tranwrd(%nrbquote("&data_sel_id"),%str( ),%str(",")));
	proc sql;
	
		create table members as
		select dataSelectionId,  memberDataSelectionId from data_sel_member where dataSelectionId in (&data_sel_id);
	quit;
	
	%if &sqlobs gt 0 %then %do;
		proc sql;
			insert into allmembers
			select dataSelectionId,  memberDataSelectionId as childid from members;
		quit;
		proc sql;
		create table allmembers_1 as
		select a.*, b.data_sel_nm as parent_nm , c.data_sel_nm as member_nm
		from allmembers a 
		inner join mfgapp.data_sel_def b  on (a.dataSelectionId=b.data_sel_def_id)
		inner join mfgapp.data_sel_def c   on (a.memberDataSelectionId=c.data_sel_def_id)

		;

		quit;
		proc sql;
			select distinct  memberDataSelectionId into :data_sel_id separated by " " from members;
		quit;
		%get_listofids(data_sel_id=&data_sel_id);
		
	%end;
	%else %do;
		%if &hier_level eq 1 %then %do;
		proc sql;
			insert into allmembers
				select &data_sel_id , ""  from members;
			quit;
			proc sql;
			create table allmembers_1 as
			select a.*, b.data_sel_nm as parent_nm , c.data_sel_nm as member_nm
			from allmembers a 
			inner join mfgapp.data_sel_def b  on (a.dataSelectionId=b.data_sel_def_id)
			inner join mfgapp.data_sel_def c   on (a.memberDataSelectionId=c.data_sel_def_id)

			;

		quit;
		%end;
	
	%end;

%mend get_listofids;

data allmembers;
length dataSelectionId  memberDataSelectionId $100.;
run;

%get_listofids(data_sel_id=&l_data_id);


%global parent_nm level recur_cnt;
%let level=0;
%let recur_cnt=0;

%macro recur(name=);

%if &recur_cnt le 200 %then %do;

	%let recur_cnt=%eval(&recur_cnt+1);
	
	proc sql;
	update allmembers_1
	set type="NOTUSED" where parent_nm in (select id from allids having order=max(order))
	;
	quit;

	proc sql;
	create table test as
	select  distinct member_nm 
	from allmembers_1
	where parent_nm="&name" and type="NOTUSED";
	quit;
	%if &sqlobs gt 0  %then %do;
		proc sql;
		 select member_nm into :l_mem 
		from test where monotonic() eq 1;
		quit;
		%let level=%eval(&level+1);
		proc sql;
		select max(order)+1 into :l_order from allids;
		insert into allids 
		select member_nm ,&l_order, &level
		from test where monotonic() eq 1;
		quit;
		proc sql;
		update allmembers_1 set type="USED" where member_nm="&l_mem" and parent_nm="&name";
		quit;
		%let parent_nm=&name;
		%recur(name=&l_mem)
	;
	%end;
	%else %do;
		%let l_parent=;
		%let level=%eval(&level-1);
		proc sql;
		create table parents as
		select parent_nm  from allmembers_1	
		where member_nm="&name" and type="USED" ;
		create table p as
		select a.parent_nm , order from parents a , allids b
		where a.parent_nm = b.id ;

		select parent_nm into :l_parent from p having order=max(order);

		%if %nrbquote(&l_parent) ne %then %do;
			%recur(name=&l_parent)
		%end;
		quit;
	%end;
%end;

%mend recur;



data allids;
length id  $100.;
length order level 8.;
id="&l_data_id";
order=1;
level=0;
output;
run;

data allmembers_1;
set allmembers_1;
drop member_nm parent_nm;
rename memberDataSelectionId=member_nm;
rename dataSelectionId=parent_nm;
type="NOTUSED";
run;

%recur(name=&l_data_id);



%macro a;
%let indent_char=unicode("\u200E \u200E \u200E\u2BC8"));
proc sql;
create table allids as
select * from allids;
quit;
%do l_r=1 %to &sqlobs;
	proc sql;
		select id into :l_id from allids where order=&l_r;
	quit;
	proc sql;
		select level into :l_level from allids where order=&l_r;
	quit;
	%do l_j=0 %to &l_level;
		%if &l_j eq 0 %then %do;
			%let indent_char= unicode("\u200E \u200E") || unicode("\u200E \u200E") || unicode("\u200E \u200E");
			%end;
			%else %do;
			%let indent_char=&indent_char.|| unicode("\u200E \u200E") || unicode("\u200E \u200E") || unicode("\u200E \u200E");
			%end;
	%end;
	proc sql;
			create table data_sel_name as
			select (&indent_char || unicode("\u200E \u200E \u200E\u2BC8")) || strip(data_sel_nm) as concat_column length=1000, 0 as chain_no,
	  0 as child_level_num,0 as childgroup_index from mfgapp.data_sel_def where data_sel_def_id="&l_id";
		quit;
		proc append nowarn data=data_sel_name base=finalcriteria force; run;
		
		%let indent_char_sub=unicode("\u200E \u200E") || unicode("\u200E \u200E") || unicode("\u200E \u200E") || unicode("\u200E \u200E");
		
		proc sql;
			create table crit as select (&indent_char || &indent_char_sub || unicode("\u200E \u200E") ) as concat_column length=1000, * from get_rowvars_all1 
			where (orig_data_sel_id="&l_id" or orig_data_sel_id="") and child_level_num eq 0;
		quit;
		proc append nowarn data=crit base=finalcriteria force; run;
		%let indent_char=;
%end;

%mend a;
%a;



data finalcriteria;
set finalcriteria;

parent_ord_no=_n_;
run;




data finalcriteria_child;
set get_rowvars_all;
if child_level_num ne 0;
keep column_nm dsfilter_operator_cd dsfilter_value_txt dsfilter_exclude_flg child_level_num childgroup_index chain_no column_fmt_nm column_data_type ; 
run;
proc append nowarn data = finalcriteria_child base=finalcriteria force; run;

data finalcriteria;
length dsfilter_exclude_flg $20.;
   set finalcriteria;
   keep column_nm dsfilter_operator_cd dsfilter_value_txt dsfilter_exclude_flg child_level_num childgroup_index chain_no column_fmt_nm column_data_type parent_ord_no concat_column; 
   dsfilter_value_txt=tranwrd(dsfilter_value_txt,'?,,','?,');
   
run;



proc sql;
select count(*) into :l_nocrit from finalcriteria where child_level_num=0;
quit;


%if &l_nocrit eq 0 %then %do;

proc sql noprint;
insert into finalcriteria
(column_nm,dsfilter_operator_cd,dsfilter_value_txt,dsfilter_exclude_flg,
child_level_num,childgroup_index,chain_no,column_fmt_nm,column_data_type, parent_ord_no, concat_column)
values ('','','','',0,0,.,'',.,0,'')
;
quit;
	
%end;

proc sort data=finalcriteria;
   by child_level_num childgroup_index chain_no;
run;

%let indent_char=unicode("\u200E \u200E") || unicode("\u200E \u200E") || unicode("\u200E \u200E"); ;

/* add rows with Child Level and Child Group numbers */
data finalcriteria(drop=a b);
   set finalcriteria end=eof;
   by child_level_num childgroup_index ;
   
   if last.child_level_num and not eof then do;
   	if child_level_num ne 0 then do;
		concat_column=(&indent_char || &indent_char ||  &indent_char || unicode("\u200E \u200E \u200E \u200E"));
	end;
      output;
      a=child_level_num+1;
      b=child_level_num;
      column_nm=compbl('CHILD_LEVEL:' || put(a,8.));
      dsfilter_operator_cd='';
      dsfilter_value_txt='';
      dsfilter_exclude_flg='';
      child_level_num=100;
      childgroup_index=childgroup_index;
      chain_no=.;
      column_fmt_nm='';
      column_data_type=.;
      concat_column=(&indent_char || unicode("\u200E \u200E \u200E\u2BC8"));
      output;

      a=1;
      column_nm=compbl('CHILD_GROUP:' || put(a,8.));
      dsfilter_operator_cd='';
      dsfilter_value_txt='';
      dsfilter_exclude_flg='';
      child_level_num=100+b+childgroup_index;
      childgroup_index=childgroup_index;
      chain_no=.;
      column_fmt_nm='';
      column_data_type=.;
      concat_column=(&indent_char || &indent_char || unicode("\u200E \u200E \u200E\u2BC8"));
      output;

   end;
   else if last.childgroup_index and not eof then do;
   	concat_column=(&indent_char || &indent_char ||  &indent_char || unicode("\u200E \u200E \u200E \u200E"));
      output;
      a=childgroup_index+1;
      column_nm=compbl('CHILD_GROUP:' || put(a,8.));
      dsfilter_operator_cd='';
      dsfilter_value_txt='';
      dsfilter_exclude_flg='';
      child_level_num=100+child_level_num+childgroup_index;
      childgroup_index=childgroup_index;
      chain_no=.;
      column_fmt_nm='';
      column_data_type=.;
      concat_column=(&indent_char || &indent_char || unicode("\u200E \u200E \u200E\u2BC8"));
      output;
   end;
   else do;
	if child_level_num ne 0 then do;
	concat_column=(&indent_char || &indent_char ||&indent_char || unicode("\u200E \u200E \u200E \u200E"));
	end;
      output;
   end;
run;


data finalcriteria;
   set finalcriteria;
   order_level=_n_;
run;

%if &l_nocrit eq 0 %then %do;
proc sql noprint;
delete * from finalcriteria where child_level_num eq 0;
quit;
%end;

/*
proc sql noprint nowarn nowarnrecurs;
		select scan(b.analysis_model_nm,1,"_")  , case when scan(analysis_model_nm,3,"_") eq "" then scan(analysis_model_nm,2,"_") else cats(scan(analysis_model_nm,2,"_"),"_",scan(step_nm,3,"_")) end 
		into :l_anlnm , :l_kg
		from mfgapp.analysis_ins_step a , mfgapp.analysis_ins b
		where a.analysis_ins_step_id="&analysisID" and a.analysis_ins_id=b.analysis_ins_id
		;
		quit;
*/

%let anlgrp=&g_analysistype._&l_kg.;

proc sql noprint;
create table analysis_parameters_lookup as select * from mfgapp.localization_value
where upcase(localization_group_id)=upcase("template_param_lookup") ;
quit;
proc sql noprint;
create table analysis_parameters as select * from mfgapp.localization_value
where upcase(localization_group_id)=upcase("&anlgrp") and basename_nm not in (select basename_nm from analysis_parameters_lookup);
quit;

proc sql noprint;
create table wrtyanl_tablecolumn_meta as select * from mfgapp.localization_value
where upcase(localization_group_id)='TABLE_COLUMN_META' and basename_nm not in (select basename_nm from analysis_parameters);
quit;

proc sql noprint;
create table REPORT_COMMON as select * from mfgapp.localization_value
where upcase(localization_group_id)='REPORT_COMMON' and basename_nm not in (select basename_nm from analysis_parameters);
quit;
proc sql noprint;
create table predefined_date as select * from mfgapp.localization_value
where upcase(localization_group_id)='PREDEFINED_DATE' and basename_nm not in (select basename_nm from analysis_parameters);
quit;



proc append data=wrtyanl_tablecolumn_meta base=localization_all force; run;
proc append data=analysis_parameters base=localization_all force; run;
proc append data=analysis_parameters_lookup base=localization_all force; run;
proc append data=REPORT_COMMON base=localization_all force; run;
proc append data=predefined_date base=localization_all force; run;


data localization_all;
set localization_all;
rename locale_nm=locale;
rename value_txt=text;
rename basename_nm=key;
run;

proc sql noprint;
   create table dist_loc as
      select distinct locale
      from localization_all;
quit;
%let l_localecnt = &sqlobs;

proc sql noprint;
   create table apply_formats as 
      select * from finalcriteria where column_fmt_nm ne "" and column_data_type ne 2 and substr(dsfilter_value_txt,1,1) ne '%';
quit;



%let l_criteriawithfmtcnt = &sqlobs;

data _null_;
set finalcriteria;
put column_nm  column_fmt_nm  column_data_type;
run;

%do l_l=1 %to &l_localecnt;
   proc sql noprint;
      select locale into :l_locale from dist_loc where monotonic() eq &l_l;
   quit;
   %do l_f=1 %to &l_criteriawithfmtcnt;
      proc sql noprint;
         create table form as
            select * from apply_formats where monotonic() eq &l_f;
         select column_fmt_nm into :l_formatnm from form;
      quit;
      
      %if &l_formatnm eq DATETIME. and &l_locale ne en %then %let l_formatnm = NLDATM.;
      
      options locale=&l_locale;
      
      data form(drop = b c newval a l);
         length b 8.;
         length locale $5.;
         length newval $1000.;
         format b &l_formatnm;
         set form;
           a=countw(dsfilter_value_txt,',');
	 	 if a > 0 then do;
	 	 	do l=1 to a;
	 
	 			b=scan(dsfilter_value_txt,l,',');
	 			c=vvalue(b);
	
	 			if l=1 then do;
	 			newval=c;
	 			end;
	 			else do;
	 			newval=strip(trim(left(newval)) || "," || trim(left(c)));
	 			end;
	 
	 		end;
	 		 dsfilter_value_txt=newval;
	 	end;
	 	else do;
	 	 	b=dsfilter_value_txt;
	          	c=vvalue(b);
	          	dsfilter_value_txt=c;
         end;
         locale="&l_locale";
      run;

      options locale=&l_baselocale;
      
      proc append data=form base=formatforlocales force; run;
   %end; /* do for each criteria with a format */ 

%end; /* do for each locale */


%if %sysfunc(exist(formatforlocales)) %then %do;
   proc sql noprint nowarn nowarnrecurs;
      create table formatforlocales as
         select a.* , unicode(text) as column_label length=5000
         from formatforlocales a, localization_all b
         where a.column_nm=b.key and a.locale=b.locale;
   quit;
%end;

proc sql noprint;
   delete * from finalcriteria where column_fmt_nm ne "" and column_data_type ne 2  and substr(dsfilter_value_txt,1,1) ne '%';
quit;



data finalcriteria;
set finalcriteria;

if substr(dsfilter_value_txt,1,1) eq '%' then do;
	dsfilter_value_txt=tranwrd(dsfilter_value_txt,'%wrna_calcperiods(p_dateVarName=g_dwLstRfrshDt,p_period=','');
	dsfilter_value_txt=tranwrd(dsfilter_value_txt,')','');
	dsfilter_operator_cd='IN';
end;
run;


proc sql noprint nowarn nowarnrecurs;
   create table finalcriteria as
      select a.* , locale , 
      case when index(column_nm , ":") gt 0 then coalesce(compbl(unicode(text) || ":" || scan(column_nm ,2, ":")),a.column_nm)
      else coalesce(unicode(text),a.column_nm) end as column_label length=5000
      from finalcriteria a left join localization_all b
      on a.column_nm=b.key or scan(a.column_nm ,1 ,':') = b.key;
quit;



%if %sysfunc(exist(formatforlocales)) %then %do;
   proc append data=formatforlocales base=finalcriteria force; run;
%end;

proc sql noprint nowarn nowarnrecurs;
   create table finalcriteria as
      select   coalesce(unicode(text),a.dsfilter_operator_cd) as dsfilter_operator_cd , a.*
      from finalcriteria a left join localization_all b
      on compress(a.dsfilter_operator_cd)=b.key and a.locale=b.locale;
quit;
proc sql noprint nowarn nowarnrecurs;
   create table finalcriteria as
      select   coalesce(unicode(text),a.dsfilter_value_txt) as dsfilter_value_txt , a.*
      from finalcriteria a left join localization_all b
      on compress(a.dsfilter_value_txt)=b.key and a.locale=b.locale and upcase(localization_group_id)='PREDEFINED_DATE';
quit;


data finalcriteria;
set finalcriteria;

if dsfilter_exclude_flg = '0' then dsfilter_exclude_flg='EXCLUDE_0';
if dsfilter_exclude_flg = '1' then dsfilter_exclude_flg='EXCLUDE_1';
run;


proc sql noprint nowarn nowarnrecurs;
   create table finalcriteria as
      select   coalesce(unicode(text),a.dsfilter_exclude_flg) as dsfilter_exclude_flg , a.*
      from finalcriteria a left join localization_all b
      on compress(a.dsfilter_exclude_flg)=b.key and a.locale=b.locale;
quit;




data finalcriteria;
   set finalcriteria;
   label column_label = "Variable";
   label dsfilter_operator_cd="Operation";
   label dsfilter_exclude_flg="Exclude";
   label dsfilter_value_txt="Selections";
   label parent_ord_no="Simple Data Selections";
   
   column_label=strip(strip(concat_column)||strip(column_label));
   
  
run;





proc sql;
select count(distinct(parent_ord_no)) into :l_group_id from finalcriteria;
quit;

	proc sql noprint;
	   select step_nm into :l_stepid
	      from mfgapp.analysis_ins_step
	      where analysis_ins_step_id="&analysisID";
	quit;
	%let l_stepid=%sysfunc(compress(&l_stepid));
 	proc sql noprint;
           select b.analysis_model_nm into :l_modelname 
              from mfgapp.analysis_ins_step a , mfgapp.analysis_ins b
              where a.analysis_ins_step_id="&analysisID" and a.analysis_ins_id=b.analysis_ins_id;
        quit;
 	%let l_modelname=%sysfunc(compress(&anlgrp));
	
	%let m_service_template = %SYSGET(SAS_URL_SERVICE_TEMPLATE);
	%put &m_service_template;
	%let BASE_URI_CREDENTIALS = %sysfunc(TRANWRD(&m_service_template.,@k8s.service.name@,sas-iot-analysis-models));
	%put &BASE_URI_CREDENTIALS;
	
	filename out "&workpath./out.txt";
	filename hdrs temp;
	 
	proc http method="GET"
	    out=out 
	    headerout=hdrs
	    url="&BASE_URI_CREDENTIALS/iotAnalysisModels/models/&l_modelname/steps/&l_stepid/templates?limit=1000"
	    OAUTH_BEARER = SAS_SERVICES
	    ; 
	run; 
	
	libname xm2 json "&workpath./out.txt";

	%macro wrna_prochttp_check_return(code);
		%if %symexist(SYS_PROCHTTP_STATUS_CODE) ne 1 %then %do;
		  %put Warning: Expected &code., but a response was not received from
		 the HTTP Procedure;
		  
		  %end;
		%else %do;
		  %if &SYS_PROCHTTP_STATUS_CODE. ne &code. %then %do;
		   %put Warning: Expected &code., but received &SYS_PROCHTTP_STATUS_CODE.
		 &SYS_PROCHTTP_STATUS_PHRASE.;
		   %end;
		%end;
		%mend wrna_prochttp_check_return;
		
		%wrna_prochttp_check_return(200);
		
	%if &SYS_PROCHTTP_STATUS_CODE. ne 200 %then %do;
		data ITEMS_PARAMETERS;
		length paramLookupId name $10.;
		length orderNo visibilityFlag 3.;
		run;
	%end;
	%else %do;
		data ITEMS_PARAMETERS;
		set xm2.ITEMS_PARAMETERS;
		run;
	%end;


data analysisoptions;
   set mfgapp.analysis_ins_step_input;
   keep analysis_param_nm param_value_txt;
   if analysis_param_nm='DATADOMAIN' then do;
      param_value_txt=translate(param_value_txt,'_',',');
   end;
   if scan(param_value_txt,1,':') eq "CUSTOM" then param_value_txt=scan(param_value_txt,2,':');
   param_value_txt=tranwrd(param_value_txt,'(','_');
   param_value_txt=tranwrd(param_value_txt,')','');
   
    analysis_param_nm=tranwrd(analysis_param_nm,'(','_');
   analysis_param_nm=tranwrd(analysis_param_nm,')','');
	
   
   if analysis_ins_step_id="&analysisID";
run;

proc sql noprint nowarn nowarnrecurs;
create table analysisoptions as 
select a.*  , b.paramLookupId, b.orderNo
from analysisoptions a ,  ITEMS_PARAMETERS b
where upcase(a.analysis_param_nm)=upcase(b.name) and visibilityFlag=1;
quit;

proc sql noprint nowarn nowarnrecurs;
   create table analysisoptions as
      select a.* , locale , coalesce(unicode(text),a.analysis_param_nm) as param_nm
      from analysisoptions a left join localization_all b
      on a.analysis_param_nm=b.key;
      
      
quit;
     
     
     proc sql noprint;
     create table multivalues as select distinct analysis_param_nm,param_value_txt from analysisoptions where index(param_value_txt,',') gt 0 and analysis_param_nm ne 'DATADOMAIN';
     quit;
     %do l_k=1 %to &sqlobs;
     	proc sql noprint;
     		select analysis_param_nm into :param_nm from multivalues where monotonic() eq &l_k;
     	quit;
     	proc sql noprint;
     		select param_value_txt into :param_value from multivalues where monotonic() eq &l_k;
     	quit;
     	data list;
     	length param_value $100;
     	varlist="&param_value";
     	do until (param_value=' ');
     			i+1;
     			param_value=scan(varlist,i,',');
     			if param_value ne ' ' then output;
     	end;
     	drop i varlist;
     	run;
     	
     	%if &param_nm eq RULESIZE %then %do;
     	
		data list;
		set list;
		if param_value='1-1' then param_value='RULESIZE_1';
		if param_value='1-2' then param_value='RULESIZE_2';
		if param_value='2-1' then param_value='RULESIZE_3';
		if param_value='2-2' then param_value='RULESIZE_4';


		run;
     	%end;
     	
     	data list;
     	
     	set list;
     	length lookupkey $100.;
     	ord=_n_;
     	lookupkey=compress("&param_nm" || "_" || param_value);
     	run;
     	
     	%if &param_nm eq RULESIZE %then %do;
     	proc sql noprint;
	     		create table values as
	     		select coalesce(unicode(text), param_value)  as param_value, coalesce(b.locale,'en') as locale , ord
	     		from list left join localization_all b
	     		 on param_value=b.key ;
     	quit;
     	%end;
     	%else %do;
     	proc sql noprint;
	     		create table values as
	     		select coalesce(unicode(text), param_value)  as param_value, coalesce(b.locale,'en') as locale , ord
	     		from list left join localization_all b
	     		 on (scan(param_value,2,'.')=b.key or lookupkey=b.key);
	     		 
	     		
     	quit;
     	
     
     	%end;
     	
     	 proc sql;
		 create table values_base as select * from values;
	 quit;
     	
     	
	proc sql;
	create table alllocales as
	select distinct locale from localization_all;
	quit;
	
	%do l_km=1 %to &sqlobs;
		proc sql;
			select distinct locale into :l_locale from alllocales where monotonic() eq &l_km; 
		quit;
		proc sql;	select count(*) into :l_localecnt from values_base where locale="&l_locale"; quit;
		%if &l_localecnt eq 0 %then %do;
			data loc_values;
			set values_base;
			locale="&l_locale";
			run;

			proc append data=loc_values base=values force; run;
		%end;
	%end;
     	
     	
     	proc sort data=values;
     	by locale ord;
     	run;
     	
     	data values(keep=param_nm param_value_txt locale);
	     	set values ;
	     	by locale ;
	     	length param_value_txt $1000.;
	     	length param_nm $100.;
			retain param_value_txt;
	     	param_nm="&param_nm";
	     	if first.locale then do;
	     		param_value_txt=trim(left(param_value));
	     	end;
	     	else do;
	
			param_value_txt=strip(trim(left(param_value_txt)) || "," || trim(left(param_value)));
	     	
	     	end;
	if last.locale then output;
	     	
     	run;
     	
     	
     	proc sql noprint;
     		
     	UPDATE analysisoptions 
	    SET param_value_txt = (SELECT param_value_txt
	                   FROM values
                   WHERE analysisoptions.analysis_param_nm = values.param_nm and analysisoptions.locale = values.locale)
                   where analysis_param_nm="&param_nm" and compress(param_value_txt)=compress("&param_value");
                   quit;
     	
     %end;



	proc sql noprint nowarn nowarnrecurs;
   create table analysisoptions as
      select a.* ,  coalesce(unicode(text),a.param_value_txt) as param_value
      from analysisoptions a left join localization_all b
      on upcase(compress(paramLookupId || "_" || a.param_value_txt))=upcase(b.key) and a.locale=b.locale and paramLookupId ne "";
   create table analysisoptions as
      select coalesce(unicode(text),a.param_value) as param_value ,a.*
      from analysisoptions a left join localization_all b
      on compress("DOMAIN" || "_" || a.param_value_txt)=b.key and a.locale=b.locale and a.analysis_param_nm='DATADOMAIN';
   create table analysisoptions as
      select coalesce(unicode(text),a.param_value) as param_value , a.*
      from analysisoptions a left join localization_all b
      on scan(param_value_txt,2,'.')=b.key and a.locale=b.locale;
      create table analysisoptions as
            select coalesce(unicode(text),a.param_value) as param_value , a.*
            from analysisoptions a left join localization_all b
      on param_value=b.key and a.locale=b.locale;
quit;


proc sql noprint nowarn nowarnrecurs;
create table analysisoptions as
select param_nm as PARAM_NM, param_value as PARAM_VALUE,locale as LOCALE,orderNo as ORDERNO
from
analysisoptions 
order by orderNo
;
quit;

data analysisoptions;
   set analysisoptions;
   label param_nm = "Analysis Property";
   label param_value = "Selection";
run;

proc sql noprint nowarn nowarnrecurs;
create table finalcriteria as
select chain_no as CHAIN_NO, child_level_num as CHILD_LEVEL_NUM, childgroup_index as CHILDGROUP_INDEX,
column_fmt_nm as COLUMN_FMT_NM, column_label as COLUMN_LABEL , column_nm as COLUMN_NM , dsfilter_exclude_flg as DSFILTER_EXCLUDE_FLG, dsfilter_operator_cd as DSFILTER_OPERATOR_CD,
dsfilter_value_txt as DSFILTER_VALUE_TXT, locale as LOCALE,order_level as ORDER_LEVEL, parent_ord_no as GROUP_ID
from finalcriteria
;
quit;




%let patchname="XMLPATCH_PROPS_SECTION";
data _null_;
file "&workpath./xmlpatch_props_section.txt";
put ', { &#34;outputname&#34;: &#34;' &patchname '&#34; , &#34;outputvalue&#34;:&#34;'  ;
put '<Section name="vi300135" label="{{localizeValue `localize(' "'DATA_SELECTION',REPORT_COMMON,'Data Selection')`}}" '">'   ;  
put '<Header>';
put '<MediaContainer target="mt2">';
put '<ResponsiveLayout orientation="horizontal" overflow="fit">';
put '<Weights mediaTarget="mt5" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt4" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt3" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '</ResponsiveLayout>';
put '</MediaContainer>';
put '</Header>';
put '<Body>';
put '<MediaContainer target="mt2">';
put '<ResponsiveLayout orientation="vertical" overflow="fit">';
put '<Weights mediaTarget="mt5" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put ' <Weights mediaTarget="mt4" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt3" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '</ResponsiveLayout>';
put '<Visual ref="ve300137" name="vi300136">';
put '<ResponsiveConstraint>';
put '<WidthConstraint>';
put '<Width mediaTarget="mt3" preferredSizeBehavior="ignore" flexibility="flexible"/>';
put '</WidthConstraint>';
put '<HeightConstraint>';
put '<Height mediaTarget="mt3" preferredSizeBehavior="ignore" value="39.11%" flexibility="shrinkable"/>';
put '</HeightConstraint>';
put '</ResponsiveConstraint>';
put '</Visual>';
put '<Visual ref="ve300142" name="vi300141">';
put '<ResponsiveConstraint>';
put '<WidthConstraint>';
put '<Width mediaTarget="mt3" preferredSizeBehavior="ignore" flexibility="flexible"/>';
put '</WidthConstraint>';
put '<HeightConstraint>';
put '<Height mediaTarget="mt3" preferredSizeBehavior="ignore" value="60.89%" flexibility="flexible"/>';
put '</HeightConstraint>';
put '</ResponsiveConstraint>';
put '</Visual>';
put '</MediaContainer>';
put '<Header>';
put '<MediaContainer target="mt2">';
put '<ResponsiveLayout orientation="horizontal" overflow="fit">';
put '<Weights mediaTarget="mt5" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt4" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt3" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '</ResponsiveLayout>';
put '</MediaContainer>';
put '</Header>';
put '</Body>';
put '</Section>';
put '<Section name="vi300189" label="{{localizeValue `localize(' "'ANALYSIS_OPTIONS',REPORT_COMMON,'Analysis Properties')`}}" '">';
put '<Body>';
put '<MediaContainer target="mt2">';
put '<ResponsiveLayout orientation="vertical" overflow="fit">';
put '<Weights mediaTarget="mt5" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt4" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '<Weights mediaTarget="mt3" unit="percent">';
put '<Weight value="100%"/>';
put '</Weights>';
put '</ResponsiveLayout>';
put '<Visual ref="ve300191" name="vi300190">';
put '<ResponsiveConstraint>';
put '<WidthConstraint>';
put '<Width mediaTarget="mt3" preferredSizeBehavior="ignore" flexibility="flexible"/>';
put '</WidthConstraint>';
put '<HeightConstraint>';
put '<Height mediaTarget="mt3" preferredSizeBehavior="ignore" flexibility="flexible"/>';
put '</HeightConstraint>';
put '</ResponsiveConstraint>';
put '</Visual>';
put '</MediaContainer>';
put '</Body>';
put '</Section>';
put '&#34; } ';
run;

%let patchname="XMLPATCH_PROPS_TABLE";
data _null_;
file "&workpath./xmlpatch_props_table.txt" mod; /* why is this one mod? */
put ', { &#34;outputname&#34;: &#34;' &patchname '&#34; , &#34;outputvalue&#34;:&#34;'  ;
put '<Table columnSizing="autoFill" resultDefinitions="dd300140" name="ve300137" data="dd300138" label="{{localizeValue `localize(' "'PARENT_SELECTIONS_TABLE',REPORT_COMMON,'Parent Selections Table')`}}" '" applyDynamicBrushes="yes" sourceInteractionVariables="bi300160 bi300161 bi300162 bi300163 bi300501">';
put '<EditorProperties>';
put '<Property key="isAutoLabel">false</Property>';
put '</EditorProperties>';
put '<Title auto="false"><P><Span>{{localizeValue `localize(' "'PARENT_SELECTIONS',REPORT_COMMON,'Parent Selections')`}}" '</Span></P></Title>';
put '<Columns sortDisabled="true">';
put '<Column variable="bi300160" isVisible="true"/>';
put '<Column variable="bi300161" isVisible="true"/>';
put '<Column variable="bi300162" isVisible="true"/>';
put '<Column variable="bi300163" isVisible="true"/>';
%if &l_group_id eq 1 %then %do;
put '<Column variable="bi300501" isVisible="false"/>';
%end;
%else %do;
put '<Column variable="bi300501" isVisible="false"/>';
%end;
put '</Columns>';
put '</Table>';
put '<Table columnSizing="autoFill" resultDefinitions="dd300145" name="ve300142" data="dd300143" label="{{localizeValue `localize(' "'SUBSET_SELECTIONS_TABLE',REPORT_COMMON,'Subset Selections Table')`}}" '" applyDynamicBrushes="yes" sourceInteractionVariables="bi300168 bi300169 bi300170 bi300171 bi300178 bi300180">';
put '<EditorProperties>';
put '<Property key="isAutoLabel">false</Property>';
put '</EditorProperties>';
put '<Title auto="false"><P><Span>{{localizeValue `localize(' "'SUBSET_SELECTIONS',REPORT_COMMON,'Subset Selections')`}}" '</Span></P></Title>';
put '<Columns sortDisabled="true">';
put '<Column variable="bi300168" isVisible="true"/>';
put '<Column variable="bi300169" isVisible="true"/>';
put '<Column variable="bi300170" isVisible="true"/>';
put '<Column variable="bi300171" isVisible="true"/>';
put '<Column variable="bi300173" isVisible="false" compactFormat="false"/>';
put '<Column variable="bi300180" isVisible="false"/>';
put '<Column variable="bi300178" isVisible="false"/>';
put '</Columns>';
put '</Table>';
put '<Table columnSizing="autoFill" resultDefinitions="dd300194" name="ve300191" data="dd300192" label="{{localizeValue `localize(' "'ANALYSIS_PROPERTIES_TABLE',REPORT_COMMON,'Analysis Properties Table')`}}" '" applyDynamicBrushes="yes" sourceInteractionVariables="bi300203 bi300204">';
put '<EditorProperties>';
put '<Property key="isAutoLabel">false</Property>';
put '</EditorProperties>';
put '<Columns sortDisabled="true">';
put '<Column variable="bi300203" isVisible="true"/>';
put '<Column variable="bi300204" isVisible="true"/>';
put '<Column variable="bi300207" isVisible="false" compactFormat="false"/>';
put '</Columns>';
put '</Table>';
put '&#34; } ';
run;


/* This small section of won't be needed if we can get the mid-tier 2-pass templatization done */
proc sql noprint;
   select analysis_ins_id into :ins_id from mfgapp.analysis_ins_step where analysis_ins_step_id="&analysisid";
quit;
%let ins_id=%sysfunc(compress(&ins_id));
data _null_; 
   length method $6 digest $128; 
   do method='CRC32'; 
      digest = hashing(method,"&ins_id"); 
      call symput('hash_ins_id' , digest );
  end;
run;
%let hash_ins_id=&hash_ins_id; /* remove trailing spaces */
%let output_ds=%sysfunc(compress(&G_ANALYSISTYPE._CRITERIA_&hash_ins_id.));
%let output_anlopt=%sysfunc(compress(&G_ANALYSISTYPE._ANLOPT_&hash_ins_id.));
/* end code to include correct output dataset names without 2-pass templatization */

%let patchname="XMLPATCH_PROPS_DATASOURCE";
data _null_;
file "&workpath./xmlpatch_props_datasource.txt";
put ', { &#34;outputname&#34;: &#34;' &patchname '&#34; , &#34;outputvalue&#34;:&#34;'  ;
put '<DataSource label="' "&output_ds" '" type="relational" name="ds300146">';
put '<CasResource server="cas-shared-default" library="QASANLOUT" table="' "&output_ds"  '" locale="en_US"/>';
put '<BusinessItemFolder>';
put '<DataItem name="bi300147" xref="CHAIN_NO" label="{{localizeValue `localize(' "'CHAIN_NO',REPORT_COMMON,'Chain No')`}}" '"/>';
put '<DataItem name="bi300148" xref="CHILD_LEVEL_NUM" usage="categorical" label="{{localizeValue `localize(' "'CHILD_LEVEL_NUM',REPORT_COMMON,'Subset level number')`}}" '"/>';
put '<DataItem name="bi300149" xref="CHILDGROUP_INDEX" usage="categorical" label="{{localizeValue `localize(' "'CHILDGROUP_INDEX',REPORT_COMMON,'Subset group index')`}}" '"/>';
put '<DataItem name="bi300150" xref="COLUMN_FMT_NM" label="{{localizeValue `localize(' "'COLUMN_FMT_NM',REPORT_COMMON,'Column format name')`}}" '"/>';
put '<DataItem name="bi300151" xref="COLUMN_LABEL" label="{{localizeValue `localize(' "'COLUMN_LABEL',REPORT_COMMON,'Variable')`}}" '"/>';
put '<DataItem name="bi300152" xref="COLUMN_NM" label="{{localizeValue `localize(' "'COLUMN_NM',REPORT_COMMON,'Column Name')`}}" '"/>';
put '<DataItem name="bi300153" xref="DSFILTER_EXCLUDE_FLG" label="{{localizeValue `localize(' "'DSFILTER_EXCLUDE_FLG',REPORT_COMMON,'Exclude')`}}" '"/>';
put '<DataItem name="bi300154" xref="DSFILTER_OPERATOR_CD" label="{{localizeValue `localize(' "'DSFILTER_OPERATOR_CD',REPORT_COMMON,'Operation')`}}" '"/>';
put '<DataItem name="bi300155" xref="DSFILTER_VALUE_TXT" label="{{localizeValue `localize(' "'DSFILTER_VALUE_TXT',REPORT_COMMON,'Values')`}}" '"/>';
put '<DataItem name="bi300156" xref="LOCALE" label="{{localizeValue `localize(' "'LOCALE',REPORT_COMMON,'Locale')`}}" '"/>';
put '<DataItem name="bi300157" xref="ORDER_LEVEL" label="{{localizeValue `localize(' "'ORDER_LEVEL',REPORT_COMMON,'Order level')`}}" '"/>';
put '<DataItem name="bi300500" xref="GROUP_ID" usage="categorical" label="{{localizeValue `localize(' "'DATA_SELECTION ',REPORT_COMMON,'Data Selection ')`}}" '"/>';
put '<PredefinedDataItem calculation="totalCount" name="bi300158" label="Frequency" usage="quantitative" format="COMMA12."/>';
put '<PredefinedDataItem calculation="totalCountPercent" name="bi300159" label="Frequency Percent" usage="quantitative" format="PERCENT20.2"/>';
put '</BusinessItemFolder>';
put '</DataSource>';
put '<DataSource label="' "&output_anlopt" '" type="relational" name="ds300195">';
put '<CasResource server="cas-shared-default" library="QASANLOUT" table="' "&output_anlopt"  '" locale="en_US"/>';
put '<BusinessItemFolder>';
put '<DataItem name="bi300196" xref="ANALYSIS_PARAM_NM" label="{{localizeValue `localize(' "'ANALYSIS_PARAM_NM',REPORT_COMMON,'Analysis Parameter Name')`}}" '"/>';
put '<DataItem name="bi300197" xref="LOCALE" label="{{localizeValue `localize(' "'LOCALE',REPORT_COMMON,'Locale')`}}" '"/>';
put '<DataItem name="bi300198" xref="PARAM_NM" label="{{localizeValue `localize(' "'PARAM_NM',REPORT_COMMON,'Parameter')`}}" '"/>';
put '<DataItem name="bi300199" xref="PARAM_VALUE" label="{{localizeValue `localize(' "'PARAM_VALUE',REPORT_COMMON,'Value')`}}" '"/>';
put '<DataItem name="bi300200" xref="PARAM_VALUE_TXT" label="{{localizeValue `localize(' "'PARAM_VALUE_TXT',REPORT_COMMON,'Analysis Parameter Value')`}}" '"/>';
put '<DataItem name="bi300210" xref="ORDERNO" label="{{localizeValue `localize(' "'ORDERNO',REPORT_COMMON,'Order number')`}}" '"/>';
put '<PredefinedDataItem calculation="totalCount" name="bi300201" label="Frequency" usage="quantitative" format="COMMA12."/>';
put '<PredefinedDataItem calculation="totalCountPercent" name="bi300202" label="Frequency Percent" usage="quantitative" format="PERCENT20.2"/>';
put '</BusinessItemFolder>';
put '</DataSource>';
put '&#34; } ';
run;

%let patchname="XMLPATCH_PROPS_PARENTDATA"; 
data _null_;
file "&workpath./xmlpatch_props_parentdata.txt";
put ', { &#34;outputname&#34;: &#34;' &patchname '&#34; , &#34;outputvalue&#34;:&#34;'  ;
put '<ParentDataDefinition childQueryRelationship="independent" status="executable" dataSource="ds300146" name="dd300138">';
put '<BusinessItems>';
put '<RelationalDataItem name="bi300160" base="bi300151"/>';
put '<RelationalDataItem name="bi300161" base="bi300154"/>';
put '<RelationalDataItem name="bi300162" base="bi300153"/>';
put '<RelationalDataItem name="bi300163" base="bi300155"/>';
put '<RelationalDataItem name="bi300164" base="bi300156"/>';
put '<RelationalDataItem name="bi300501" base="bi300500"/>';
put '<RelationalFilterItem name="bi300165">';
put '<EditorProperties>';
put '<Property key="complexity">SINGLE_DATA_ITEM</Property>';
put '<Property key="interactiveEditingAllowed">TRUE</Property>';
put '</EditorProperties>';
put '<Expression>or(in(${bi300164,binned},&apos;{{.LOCALE}}&apos;),ismissing(${bi300164,binned}))</Expression>';
put '</RelationalFilterItem>';
put '<RelationalDataItem name="bi300174" base="bi300148"/>';
put '<RelationalFilterItem name="bi300175">';
put '<EditorProperties>';
put '<Property key="complexity">SINGLE_DATA_ITEM</Property>';
put '<Property key="interactiveEditingAllowed">TRUE</Property>';
put '</EditorProperties>';
put '<Expression>in(${bi300174,binned},0)</Expression>';
put '</RelationalFilterItem>';
put '</BusinessItems>';
put '<DataDefinition dataSource="ds300146" type="relational" name="dd300139">';
put '<RelationalQuery detail="false">';
put '<Axes>';
put '<Axis type="column">';
put '<BusinessItem ref="bi300160"/>';
put '<BusinessItem ref="bi300161"/>';
put '<BusinessItem ref="bi300162"/>';
put '<BusinessItem ref="bi300163"/>';
put '<BusinessItem ref="bi300501"/>';
put '</Axis>';
put '</Axes>';
put '<SortItems>';
%if &l_group_id eq 1 %then %do;
put '<SortItem ref="bi300160" sortDirection="ascending"/>';
%end;
%else %do;
put '<SortItem ref="bi300501" sortDirection="ascending"/>';
%end;
put '</SortItems>';
put '</RelationalQuery>';
put '<ResultDefinitions>';
put '<ResultDefinition purpose="primary" maxRowsLookup="listTable" maxRowsBehavior="truncate" name="dd300140"/>';
put '</ResultDefinitions>';
put '</DataDefinition>';
put '<AppliedFilters>';
put '<DetailFilters>';
put '<BusinessItem ref="bi300165"/>';
put '<BusinessItem ref="bi300175"/>';
put '</DetailFilters>';
put '</AppliedFilters>';
put '</ParentDataDefinition>';
put '<ParentDataDefinition childQueryRelationship="independent" status="executable" dataSource="ds300146" name="dd300143">';
put '<BusinessItems>';
put '<RelationalDataItem name="bi300168" base="bi300151"/>';
put '<RelationalDataItem name="bi300169" base="bi300154"/>';
put '<RelationalDataItem name="bi300170" base="bi300153"/>';
put '<RelationalDataItem name="bi300171" base="bi300155"/>';
put '<RelationalDataItem name="bi300173" base="bi300157"/>';
put '<RelationalDataItem name="bi300176" base="bi300156"/>';
put '<RelationalFilterItem name="bi300177">';
put '<EditorProperties>';
put '<Property key="complexity">SINGLE_DATA_ITEM</Property>';
put '<Property key="interactiveEditingAllowed">TRUE</Property>';
put '</EditorProperties>';
put '<Expression>or(in(${bi300176,binned},&apos;{{.LOCALE}}&apos;),ismissing(${bi300176,binned}))</Expression>';
put '</RelationalFilterItem>';
put '<RelationalDataItem name="bi300178" base="bi300148"/>';
put '<RelationalFilterItem label="{{localizeValue `localize(' "'Subset_filter',REPORT_COMMON,'Subset level filter')`}}" '" name="bi300179" >';


put '<EditorProperties>';
put '<Property key="complexity">ADVANCED</Property>';
put '<Property key="interactiveEditingAllowed">FALSE</Property>';
put '</EditorProperties>';
put '<Expression>notIn(${bi300178,binned},0)</Expression>';
put '</RelationalFilterItem>';
put '<RelationalDataItem name="bi300180" base="bi300149"/>';
put '</BusinessItems>';
put '<DataDefinition dataSource="ds300146" type="relational" name="dd300144">';
put '<RelationalQuery detail="false">';
put '<Axes>';
put '<Axis type="column">';
put '<BusinessItem ref="bi300168"/>';
put '<BusinessItem ref="bi300169"/>';
put '<BusinessItem ref="bi300170"/>';
put '<BusinessItem ref="bi300171"/>';
put '<BusinessItem ref="bi300173"/>';
put '<BusinessItem ref="bi300180"/>';
put '<BusinessItem ref="bi300178"/>';
put '</Axis>';
put '</Axes>';
put '<SortItems>';
put '<SortItem ref="bi300173" sortDirection="ascending"/>';
put '</SortItems>';
put '</RelationalQuery>';
put '<ResultDefinitions>';
put '<ResultDefinition purpose="primary" maxRowsLookup="listTable" maxRowsBehavior="truncate" name="dd300145"/>';
put '</ResultDefinitions>';
put '</DataDefinition>';
put '<AppliedFilters>';
put '<DetailFilters>';
put '<BusinessItem ref="bi300177"/>';
put '<BusinessItem ref="bi300179"/>';
put '</DetailFilters>';
put '</AppliedFilters>';
put '</ParentDataDefinition>';
put '<ParentDataDefinition childQueryRelationship="independent" status="executable" dataSource="ds300195" name="dd300192">';
put '<BusinessItems>';
put '<RelationalDataItem name="bi300203" base="bi300198"/>';
put '<RelationalDataItem name="bi300204" base="bi300199"/>';
put '<RelationalDataItem name="bi300205" base="bi300197"/>';
put '<RelationalDataItem name="bi300207" base="bi300210"/>';
put '<RelationalFilterItem name="bi300206">';
put '<EditorProperties>';
put '<Property key="complexity">SINGLE_DATA_ITEM</Property>';
put '<Property key="interactiveEditingAllowed">TRUE</Property>';
put '</EditorProperties>';
put '<Expression>in(${bi300205,binned},&apos;{{.LOCALE}}&apos;)</Expression>';
put '</RelationalFilterItem>';
put '</BusinessItems>';
put '<DataDefinition dataSource="ds300195" type="relational" name="dd300193">';
put '<RelationalQuery detail="false">';
put '<Axes>';
put '<Axis type="column">';
put '<BusinessItem ref="bi300203"/>';
put '<BusinessItem ref="bi300204"/>';
put '<BusinessItem ref="bi300207"/>';
put '</Axis>';
put '</Axes>';
put '<SortItems>';
put '<SortItem ref="bi300207" sortDirection="ascending"/>';
put '</SortItems>';
put '</RelationalQuery>';
put '<ResultDefinitions>';
put '<ResultDefinition purpose="primary" maxRowsLookup="listTable" maxRowsBehavior="truncate" name="dd300194"/>';
put '</ResultDefinitions>';
put '</DataDefinition>';
put '<AppliedFilters>';
put '<DetailFilters>';
put '<BusinessItem ref="bi300206"/>';
put '</DetailFilters>';
put '</AppliedFilters>';
put '</ParentDataDefinition>';
put '&#34; } ';
run;

/* wrap all patches into one file */
data _null_;
     length value $32000.;
     file "&workpath./xmlpatch_props.txt";
     infile "&workpath./xmlpatch_props_*.txt";
     input;
     value=tranwrd(_infile_,'"', '\"');
     value=tranwrd(value,'&#34;', '"');
      put value @;
     
run;

%mend;

/* * ANL_DRIVER: The only parameter passed is the analysisID - the     *
 * exact method of passing this parameter may change     *
 * (macro parameter, global variable, etc.).             */     
%macro anl_driver(analysisID=,g_cas=,g_metadata=,anl_type=, anlnm=) ;
%if %length(&SYSERRORTEXT) %then %do;

%put ERROR: %str( );

%end;
%global driver_starttime;
%let driver_starttime=%sysfunc(datetime());
%put "Started at %sysfunc(putn(%sysfunc(datetime()),datetime.))";

%global g_casSessionId  ;
%*qas_getconnections(g_cas=&g_cas , g_metadata=&g_metadata);

%global l_anlnm l_kg g_analysisnamexists;
	%if &anlnm eq %str() %then %do;
		proc sql noprint nowarn nowarnrecurs;
		select scan(b.analysis_model_nm,1,"_")  , case when scan(analysis_model_nm,3,"_") eq "" then scan(analysis_model_nm,2,"_") else cats(scan(analysis_model_nm,2,"_"),"_",scan(step_nm,3,"_")) end 
		into :l_anlnm , :l_kg
		from mfgapp.analysis_ins_step a , mfgapp.analysis_ins b
		where a.analysis_ins_step_id="&analysisID" and a.analysis_ins_id=b.analysis_ins_id
		;
		quit;
		%let g_analysisnamexists=N;
	%end;
	%else %do;
		/* parsing for custom analyses where analsyis_model_nm might look like PIE */
	   %let l_anlnm = %upcase(&anlnm);
	   proc sql noprint nowarn nowarnrecurs;
		  select model_group_cd 
			 into :l_kg
			 from mfgapp.model_def
			 where upcase(model_nm) = "&l_anlnm"
			 ;
	   quit;
       %let l_anlnm = %sysfunc(scan(&l_anlnm,1,'_'));
	   %let g_analysisnamexists=Y;
	%end;


proc sql noprint nowarn nowarnrecurs;
select analysis_ins_id into :ins_id from mfgapp.analysis_ins_step where analysis_ins_step_id="&analysisid";
quit;
%let ins_id=%sysfunc(compress(&ins_id));
data _null_; 
	 length method $6 digest $128; 
	 do method='CRC32'; 
	 digest = hashing(method,"&ins_id"); 
	 call symput('hash_ins_id' , digest );
	 end;
	 run;
	 
proc sql noprint nowarn nowarnrecurs;
	create table instance_names as 
	select "&hash_ins_id" as instance_nm ,scan(step_nm,1,"_") as analysis_type_cd , data_as_of
	from mfgapp.analysis_ins_step a , mfgapp.analysis_ins b
	where a.analysis_ins_step_id="&analysisID" and a.analysis_ins_id=b.analysis_ins_id
	;
	quit;
	
	data instance_names;
	set instance_names;
	length instancename $1000.;
	instancename=tranwrd(instance_nm , "'","''");
	run;
	
	proc sql noprint nowarn nowarnrecurs;
	select analysis_type_cd , strip("'" || strip(instancename) || "'") ,put(data_as_of,32.)
	into :l_analysis_type_cd , :l_instancename , :l_dt
	from instance_names;	
	
	quit;
	
	
	%if &l_analysis_type_cd eq EIENTERPRISE %then %do;
	
		proc sql noprint nowarn nowarnrecurs;
				
		select count(*) into :l_eianalyzed from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&analysisid"
		and analysis_param_nm eq "PARENT_ANALYSIS_ID" and trim(left(param_value_txt)) ne "";
		%if &l_eianalyzed le 0 %then %do;
	
			%let g_recon =;
			%let g_comreset=;
			proc sql noprint nowarn nowarnrecurs;
			select param_value_txt into :g_recon from mfgapp.analysis_ins_step_input where upcase(analysis_param_nm) ='RECONCILE' and analysis_ins_step_id="&analysisID";
			select param_value_txt into :g_comreset from mfgapp.analysis_ins_step_input where upcase(analysis_param_nm) ='COMPLETERESET' and analysis_ins_step_id="&analysisID";
			quit;
		
			%if &g_recon eq TRUE %then %do;
				%if &g_comreset eq TRUE %then %do;
					cas mysession terminate;
					CAS myS1 SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );	
					%qas_delete_output(analysistype=&l_analysis_type_cd,instancenm=&l_instancename);
					%qas_delete_output(analysistype=EIENT,instancenm=&l_instancename,allversions=Y);
					cas myS1 terminate;
					CAS mySession SESSOPTS=(CASLIB=&g_caslib);
					libname MYCAS CAS sessref=mysession;
				%end;
				%else %do;
					quit;
					cas mysession terminate;
					CAS myS1 SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );
					%qas_load_delete_sashdat(parameter=load,instancenm=&l_instancename);
					/*data dt;
					length dt 8.;
					dt="&l_dataasof"dt;
					run;
					proc sql noprint nowarn nowarnrecurs;
					select put(dt,32.) into :l_dt from dt;
					quit;
					*/
					
					%global g_refreshdate;
					%qas_getdwrefreshdate(p_rtrnVar=g_refreshdate,l_keydim=PRODUCT);
					%if &l_dt < &g_refreshdate %then %do;
					
					%end;
					%else %do;
					
										
						%qas_copy_last_eient_output(analysisname=&l_instancename);
					
					%end;
					quit;
					cas myS1 terminate;
					CAS mySession SESSOPTS=(CASLIB=&g_caslib);
					libname MYCAS CAS sessref=mysession;
				%end;
			
			%end;
			%else %do;
				cas mysession terminate;
				CAS myS1 SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );	
				%qas_delete_output(analysistype=&l_analysis_type_cd,instancenm=&l_instancename);
				%qas_delete_output(analysistype=EIENT,instancenm=&l_instancename,allversions=Y);
				cas myS1 terminate;
				CAS mySession SESSOPTS=(CASLIB=&g_caslib);
				libname MYCAS CAS sessref=mysession;
			%end;
		%end;
	%end;
	%else %do;
		
		 %if &anl_type ne SCORING %then %do;
		 		cas mysession terminate;
		 		CAS myS1 SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );	
		 		%qas_delete_output(analysistype=&l_analysis_type_cd,instancenm=&l_instancename);
		 		 cas myS1 terminate;
		 	  	 CAS mySession SESSOPTS=(CASLIB=&g_caslib);
		 		 libname MYCAS CAS sessref=mysession;
		%END;
	
	%end;
	
proc sql noprint nowarn nowarnrecurs;
	select analysis_ins_id into :insid from mfgapp.analysis_ins_step where analysis_ins_step_id="&analysisid";
	%let insid=%sysfunc(Compress(&insid));
	select count(*) into :l_childcnt from mfgapp.analysis_ins where analysis_ins_id="&insid" and trim(left(parent_analysis_ins_id)) ne "" ;
	%if &l_childcnt gt 0 %then %do;
		proc sql;
			select parent_analysis_ins_id into :l_parentid from mfgapp.analysis_ins where analysis_ins_id="&insid";
			 select analysis_ins_step_id into :l_parent_stepid from mfgapp.analysis_ins_step where analysis_ins_id="&l_parentid";
		quit;
		cas mysession terminate;
		CAS myS SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );
		%afi_load_anl_casoutput(analysisid=&l_parent_stepid);
		cas myS terminate;
		CAS mySession SESSOPTS=(CASLIB=&g_caslib);
		libname MYCAS CAS sessref=mysession;
		proc sql noprint nowarn nowarnrecurs;
			select count(*) into :l_criteriacnt from mfgapp.filter_criteria where criteria_group_id="&insid";
		quit;
	
		%if &l_criteriacnt le 0 %then %do;
			%global g_callfromdrive;
			%let g_callfromdrive=Y;
			%qas_addsubsetclause(analysisid=&insid);
			%local vars;
	 
			proc sql noprint nowarn nowarnrecurs noprint;
					 select name into: vars separated by ' '
					  from dictionary.macros
							  where scope='GLOBAL' and substr(upcase(name),1,2)="G_"
					   and not name contains 'SYS_SQL_IP_';
			quit;
		 
			%symdel &vars;
			%global g_casSessionId  ;
			%qas_getconnections(g_cas=&g_cas , g_metadata=&g_metadata,G_GETPGMETA=N);
		%end;
	%end;
quit;
	
%if %nrbquote(&syserrortext) eq %then %do;   
	%if &l_kg ne PRODUCT %then %do;
		%if &l_anlnm eq EXPLORATION or &l_anlnm eq PREDICTIVE %then %do;
			%anl_getexp_pred_attributes(&analysisID,&l_anlnm,&l_kg);
			
		%end;
		%if &l_anlnm eq STABILITY  %then %do;
			%anl_getstab_attributes(&analysisID,&l_anlnm,&l_kg);
			
		%end;
	%end;
	%else %do;
		%if &l_anlnm eq EIENTERPRISE or &l_anlnm eq EIANALYTIC or &l_anlnm eq EITHRESHOLD %then %do;
						
			proc sql noprint nowarn nowarnrecurs;
				
				select count(*) into :l_eianalyzed from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&analysisid"
				and analysis_param_nm eq "PARENT_ANALYSIS_ID" and trim(left(param_value_txt)) ne "";
				%if &l_eianalyzed gt 0 %then %do;
									
					
					proc sql noprint nowarn nowarnrecurs;
						select param_value_txt into :l_commment_id from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&analysisid"
						and analysis_param_nm eq "COMMENT_ID";
						
						select param_value_txt into :l_PARENT_ANALYSIS_OWNER from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&analysisid" and analysis_param_nm eq "PARENT_ANALYSIS_OWNER";
						select param_value_txt into :l_PARENT_ANALYSIS_ID from mfgapp.analysis_ins_step_input where analysis_ins_step_id="&analysisid" and analysis_param_nm eq "PARENT_ANALYSIS_ID";
						select analysis_ins_id into :insid from mfgapp.analysis_ins_step where analysis_ins_step_id="&analysisid";
						select data_selection_id into :dsid from mfgapp.analysis_ins where analysis_ins_id="&insid";
						%let dsid=%sysfunc(Compress(&dsid));
						
						%let insid=%sysfunc(Compress(&insid));
						%let l_commment_id=%nrbquote(&l_commment_id);
						%let l_PARENT_ANALYSIS_OWNER=%sysfunc(Compress(&l_PARENT_ANALYSIS_OWNER));
						%let l_PARENT_ANALYSIS_ID=%sysfunc(Compress(&l_PARENT_ANALYSIS_ID));
						
						
						select analysis_ins_step_id into :l_parent_step_id from mfgapp.analysis_ins_step where analysis_ins_id="&l_PARENT_ANALYSIS_ID";
						%let l_parent_step_id=%sysfunc(Compress(&l_parent_step_id));
						
						
										
						select count(*) into :l_childcriteria from mfgapp.filter_criteria where criteria_group_id="&dsid"
						and lowcase(dsmart_column_nm) ='macrovar';
						
					quit;
					cas mysession terminate;
					CAS myS SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99 );
					%afi_load_anl_casoutput(analysisid=&l_parent_step_id);
					cas myS terminate;
					CAS mySession SESSOPTS=(CASLIB=&g_caslib);
					libname MYCAS CAS sessref=mysession;
						
					%if &l_childcriteria le 0 and &l_anlnm ne EITHRESHOLD %then %do;
							%qas_addsubsetclause_ei(
							newdataselectionid=%nrbquote(&dsid),
							parent_analysisid=%nrbquote(&l_PARENT_ANALYSIS_ID),
							parent_analysisstepid=%nrbquote(&l_parent_step_id),
							parent_analysisowner=%nrbquote(&l_PARENT_ANALYSIS_OWNER),
							
							comment_id=%nrbquote(&l_commment_id),
							newanalysisid=%nrbquote(&insid)
							);
					%end;
					
					proc sql noprint nowarn nowarnrecurs;
						select value_txt into :l_alert_type from mfgapp.filter_criteria where criteria_group_id="&dsid"
						and upcase(column_nm) eq "ALERT_TYPE";
					quit;
					%global g_FPERIODVARCMONTH;
					
					proc sql noprint nowarn nowarnrecurs;
						select param_value_txt into :g_FPERIODVARCMONTH from mfgapp.analysis_ins_step_input 
						where analysis_ins_step_id="&analysisid" and analysis_param_nm eq "FPERIODVARCMONTH";
					quit;
					%let g_FPERIODVARCMONTH=&g_FPERIODVARCMONTH;
						
					%qas_copyeioutput(
					new_analysisstepid=%nrbquote(&analysisid),
					parent_analysisstepid=%nrbquote(&l_parent_step_id),
					parentanalysisowner=%nrbquote(&l_PARENT_ANALYSIS_OWNER),
					comment_id=%nrbquote(&l_commment_id),
					alert_type=&l_alert_type
					);
					
					%qas_cas_output_lifetime(analysisid=&analysisID);
					%goto exit;
				%end;
		%end;
		/* Set global variables for required analysis attributes */
		%anl_getanalysisattributes(&analysisID);
		/* Call the solution specifc data prep             *
		 * Implementation of this is up to the individual  *
		 * solutions, but this is an appropriate place to: *
		 * - pull data from the mart                       *
		 * - join tables                                   *  
		 * - apply business calculations                   * 
		 * - summarize the data                            */
        %let g_analysistype = &l_anlnm;
		%if %nrbquote(&syserrortext) ne %then %do;
		%end;
		%else %do;
			%if &g_analysistype eq EIENTERPRISE %then %do;
				%wrna_eienterprisedataprep(analysisID=&analysisID);
							
			%end;
			%else %do;
			
				%&g_solutionCD._dataprep;
			%end;
		
		%if %upcase(&g_analysistype) NE DETAIL %then
		%do; /*Changes made for Details analysis*/
		%if %upcase(&g_analysistype) EQ EIENTERPRISE %then %do;
		
		%wrna_eienterpriseoutput(analysisID=&analysisID,g_cas=&g_cas);
		
		
		%end;
		%else %do;
			%anl_call&g_analysisType.output;
		%end;
		%end;
		%end;
	%end;
	
	%if %nrbquote(&syserrortext) ne %then %do;
		 data test;
		 set datatocreateerror;
		 run;
	%end;
	%else %do;
		%qas_cas_output_lifetime(analysisid=&analysisID);
	%end;
	
		
	
 %if %sysfunc(exist(EISUBJOBS)) %then %do;
 
	proc sql noprint nowarn nowarnrecurs;
	create table eisubjobs_hier 
	as select a.* , b.*
	from eihierarchy a , eisubjobs b
	where a.dhid=b.dhid;
	quit;
 
	%let l_byvar =%sysfunc(tranwrd(%quote(&g_byvar),%str(,),%str( )));
	data _null_;
	set eisubjobs_hier end=eof;
	if _n_=1 then 
	put "*************************************************************************************************";
	put  &l_byvar  status  log;
	if eof then 
	put "*************************************************************************************************";
	run;
	
	 
	
 %end;
%end;
%else %do;
data test;
		 set datatocreateerror;
		 run;
%end;
 	%exit:
	
	
	 %put "Ended at %sysfunc(putn(%sysfunc(datetime()),datetime.))";
	    %let driver_end=%sysfunc(datetime());
	    %put &driver_starttime;
	    %put &driver_end;
	    %let driver_time=%sysevalf(&driver_end-&driver_starttime);
	    %put &driver_time;
    %put "Total time taken is %sysfunc(putn(&driver_time,time8.))";
%mend anl_driver;

/* mid-tier will only resolve ? params once, so store these */
/* values in macro vars so they can be reused               */
%let g_cas=%nrbquote({"name":"cas-shared-default","description":"controller","host":"sas-cas-server-default-client","port":5570,"restPort":8777,"casLib":"QASMartStore","casUser":"germsz","casSessionID":"da92981a-8ad9-dd42-b0fc-26014b2b5a7f"});
%let g_metadata=%nrbquote();
%let analysisID=%nrbquote(70e6ea9a-3439-442b-b4e0-866d0bf9712e);

/* Connect to the postgres metadata and retrieve user selected params */
%qas_getconnections(g_cas=&g_cas, g_metadata=&g_metadata);
%anl_getanalysisattributes(&analysisID);

%if &g_datasource=DATSELECTION %then %do;
   /* use anl_driver to pull data from AIoT mart using the same process as STABILITY MONITORING */

   %anl_driver(analysisID=&analysisID,g_cas=&g_cas,g_metadata=&g_metadata,anlnm=STABILITY_ASSET);
%end;  /* DATSELECTION */

%else %do;
   /* rename the provided table for use in the next step */

   %global G_INSTANCEID;
   proc sql noprint;
	select analysis_ins_id into :G_INSTANCEID
	from mfgapp.analysis_ins_step
	where analysis_ins_step_id="&G_ANALYSISID";
   quit;
   %put &=G_INSTANCEID.;

   %let G_ANALYSISTYPE=SVDD;
   %let g_casanlout=QASAnlOut;

   %put NOTE: Selected calib is: &g_sel_caslib;
   %put NOTE: Selected sas table is: &g_sel_sastable;
 
   CAS outsess SESSOPTS=(CASLIB=&g_casanlout TIMEOUT=99);
   libname qasanl CAS datalimit=all sessref=outsess;
 
   CAS selsess SESSOPTS=(CASLIB=&g_sel_caslib TIMEOUT=99);
   libname selcas CAS datalimit=all sessref=selsess;

   /* Delete all tables being created for use in step 2 */
   proc casutil incaslib="&g_casanlout.";
      droptable casdata="&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm" quiet;
      droptable casdata="&G_ANALYSISTYPE._TAGS_&g_instance_nm" quiet;
      droptable casdata="&G_ANALYSISTYPE._ASSETS_&g_instance_nm" quiet;
   quit;

   /* Save the selected table as the TRANSPOSE table */
   data qasanl.&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm (promote=yes);
       set selcas.&g_sel_sastable. (rename=(ASSET_ID=PAM_ASSET_ID));
   run;

   /* Create a table that lists all the assets and tags provided in the selected table */
   proc transpose data=qasanl.&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm out=untransposed (rename=(_NAME_=TAG_ID) where=(col1 ne .));
      by pam_asset_id datetime;
   quit;

   proc sql noprint;
      create table tags as
         select distinct tag_id, tag_id as TAG_ID_DESC, pam_asset_id, pam_asset_id as PAM_ASSET_ID_DESC, tag_id as TAG_COLUMN_NM
         from untransposed;
      create table assets as
         select distinct pam_asset_id, pam_asset_id_desc
         from tags;
   quit;

   data qasanl.&G_ANALYSISTYPE._TAGS_&g_instance_nm (promote=yes);
       set work.tags;
   run;
   data qasanl.&G_ANALYSISTYPE._ASSETS_&g_instance_nm (promote=yes);
       set work.assets;
   run;


   proc cas;
      session outsess;
      table.save / caslib="QASAnlOut" compress=true name="&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm..sashdat" 
                   replace=true table={caslib="QASAnlOut",name="&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm"};
      table.save / caslib="QASAnlOut" compress=true name="&G_ANALYSISTYPE._TAGS_&g_instance_nm..sashdat" 
                   replace=true table={caslib="QASAnlOut",name="&G_ANALYSISTYPE._TAGS_&g_instance_nm"};
      table.save / caslib="QASAnlOut" compress=true name="&G_ANALYSISTYPE._ASSETS_&g_instance_nm..sashdat" 
                   replace=true table={caslib="QASAnlOut",name="&G_ANALYSISTYPE._ASSETS_&g_instance_nm"};
   run;

   /* Save info about the tables created above for us the in the following steps and VA outputs */
   filename json_in temp;
   data _null_;
   file json_in;
   	put '{ "analysisStepOutputParams": [ ';
   	put ' { "outputname": "TARGET_VAR_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._TAGS_&g_instance_nm" '"} ,';
    put ' { "outputname": "ASSET_VAR_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._ASSETS_&g_instance_nm" '"} ,';
   	put ' { "outputname": "TRANSPOSE_TABLE" , "outputvalue" : "' "&G_ANALYSISTYPE._TRANSPOSE_&g_instance_nm" '"} ,';
   	put ' { "outputname": "TARGET_VAR_COLUMN_NAME" , "outputvalue" : "' "TAG_COLUMN_NM" '"} ,';
   	put ' { "outputname": "TARGET_VAR_KEY_COLUMN" , "outputvalue" : "' "TAG_ID" '"} ,';
   	put ' { "outputname": "TARGET_VAR_VALUE_COLUMN" , "outputvalue" : "' "TAG_ID_DESC" '"} ,';
   	put ' { "outputname": "ASSET_VAR_KEY_COLUMN" , "outputvalue" : "' "PAM_ASSET_ID" '"} , ';
   	put ' { "outputname": "CASLIB" , "outputvalue" : "' "QASAnlOut" '"} , ';
   	put ' { "outputname": "ASSET_VAR_VALUE_COLUMN" , "outputvalue" : "' "PAM_ASSET_ID_DESC" '"}  ';
   	put '  ] }';
   run;

   %let SERVICE_TEMPLATE=%SYSGET(SAS_URL_SERVICE_TEMPLATE);
   %let BASE_URI_CREDENTIALS=%sysfunc(TRANWRD(&SERVICE_TEMPLATE, @k8s.service.name@, sas-iot-analysis));

   filename resp temp;
   proc http method="POST"
	url="&BASE_URI_CREDENTIALS./iotAnalysis/analyses/&G_INSTANCEID./steps/&G_ANALYSISID./outputParams"
	OAUTH_BEARER=SAS_SERVICES ct="application/json"
	in=json_in out=resp;
   quit;
%end;  /* SASTABLE */
