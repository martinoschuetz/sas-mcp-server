/************************************************************************************************************************************************************************************/
/****Authors: Piotr Pilat, Michal Kurcewicz, SAS Poland ***************************************************************************************************************************/
/*** This macro allows to read Forecast Studio project and save all candidate models forecast (not reconciled) to an external file.*************************************************/
/*** This macro works on the copy of FS project model repository, however it is recommended to (at least if used for the first time) copy the project and run macro on this copy.***/ 
/*** Maco ALL_FORECASTS has following parameters:***********************************************************************************************************************************/
/*** PROJECTNAME - the name of SAS FS project (or the copy of original project) ****************************************************************************************************/
/*** USER= , PASSWORD = - login and passowrd of SAS user ***************************************************************************************************************************/
/*** OUTFORLIB = - output SAS library. The library will contain as many output tables as the number of hierarchy levels in the SAS FS project **************************************/
/*** with following structure: OUTFOR_LIB<i> with <i> indicating the ordinal number of hierarchy level (e.g. top hierarchy level has output table name OUTFOR_LIB1)*****************/
/*** Macro uses the facility of %fslogin and %fsload to read the files location and parameters specification of SAS FS project******************************************************/ 
/***********************************************************************************************************************************************************************************/

%macro all_forecasts(projectname=, user=, password=, outforlib=);
	
	%fslogin(user=&user, password=&password);
	%fsload(projectname=&projectname);
	
	%symdel HPF_READ_ONLY;

	%include "&hpf_include";

	%let time_id2 = %sysfunc(cat(&HPF_TIMEID,2));

	%do i=1 %to &HPF_NUM_LEVELS;
	
		data _null_;
			do _N_=1 by 1 until (eof);

				set &&HPF_LEVEL_LIBNAME&i...est END=eof;
						cnt = left(put(_N_,6.));
							%let filter = _SELECT_;
								%if &i. = 1 %then %do;   /* Top level */
									call symputx("lib&i._selectname"||cnt, &filter);	
									call symputx("lib&i._by","");	
								%end;
								%if &i. > 1 %then %do;
									%let by_group = by ; 
									%do k=2 %to &i.;
										%let j = %eval(&k - 1);
										%let by = &&HPF_BYVAR&j.;
										/* %put !!!!&by!!!!; */
										%let filter = &filter||""||&by;
										%let by_group = &by_group &by; 
									%end;
									call symputx("lib&i._selectname"||cnt,&filter);
									call symputx("lib&i._by","&by_group;");
								%end;
				if (eof) then DO;
					call symputx("lib&i._nhierseries", cnt);
				end;
			end;
		run;

	%end;

	%do i=1 %to &HPF_NUM_LEVELS;;

		%do j=1 %to &&lib&i._nhierseries;
			
			%let where = 1;
			
			%if i > 1 %then %do;
				%do k=2 %to &i.;
					%let lv = %eval(&k - 1);
					%let where = &where and &&HPF_BYVAR&lv. =  "%scan(&&&lib&i._SELECTNAME&j.,&k.," ")";
				%end;
			%end;

			Proc SQL NOPRINT;

					CREATE TABLE outfor_lib&i.hier&j. 
						AS SELECT * 
							FROM &&HPF_LEVEL_LIBNAME&i...DATA
								WHERE &where
					; 

					SELECT DISTINCT _MODEL_ 
					INTO :model1-:model99
						FROM &&HPF_LEVEL_LIBNAME&i...outstatselect
							WHERE &where 
					;
			QUIT;
	

			%let modelcnt = &sqlobs;

			Proc CATALOG cat = &&HPF_LEVEL_LIBNAME&i...LevModRep;
				COPY out =  LevModRep;
			QUIT;

	
			%do m=1 %to &modelcnt;

					Proc HPFSELECT
						MODELREPOSITORY = LevModRep
	  					SELECTNAME=%scan(&&&lib&i._SELECTNAME&j.,1," ")
						;
	   					DIAGNOSE
						%if %symexist(HPF_DIAGNOSE_SEASONTEST) %then %do;
					    	SEASONTEST=(siglevel=&HPF_DIAGNOSE_SEASONTEST)
						%end;
						%else %do;
	    					SEASONTEST=NONE
						%end;
	  					INTERMITTENT= &HPF_DIAGNOSE_INTERMITTENT 
	     				;
	     				SELECT
                        %if %symexist(HPF_SELECT_HOLDOUT) %then %do;
							HOLDOUT= &HPF_SELECT_HOLDOUT
							HOLDOUTPCT = &HPF_SELECT_HOLDOUTPCT
						%end;
						%else %do;
							HOLDOUT=0
							HOLDOUTPCT=100.0
						%end;
						CRITERION= &HPF_SELECT_CRITERION
				    	CHOOSE= &&model&m.
	    				;
	    				SPEC &&model&m. ;
					RUN;



					 Proc HPFENGINE data=&&HPF_LEVEL_LIBNAME&i...DATA(where=(&where)) 
							inest=&&HPF_LEVEL_LIBNAME&i...est(where=(&where))

							seasonality=&HPF_SEASONALITY
							errorcontrol=(severity=ALL, stage=(PROCEDURELEVEL DATAPREP SELECTION ESTIMATION FORECASTING))
							exceptions=catch
							modelrepository = LevModRep
							task = select( 
										   alpha=&HPF_FORECAST_ALPHA 
										   criterion=&HPF_SELECT_CRITERION 
										   %if %symexist(HPF_SELECT_HOLDOUT) %then %do;
											holdout=&HPF_SELECT_HOLDOUT holdoutpct=&HPF_SELECT_HOLDOUTPCT
										   %end;
										   minobs=&HPF_SELECT_MINOBS_NON_MEAN
										   minobs=(season=&HPF_SELECT_MINOBS_SEASONAL) 
										   minobs=(trend=&HPF_SELECT_MINOBS_TREND)
										   %if %symexist(HPF_DIAGNOSE_SEASONTEST) %then %do;
										    seasontest=(siglevel=&HPF_DIAGNOSE_SEASONTEST)
										   %end;
										   %else %do;
										    seasontest=none 
										   %end;
										   intermittent=&HPF_DIAGNOSE_INTERMITTENT override
										  )
							back=&HPF_BACK 
							components=&HPF_COMPONENTS 
							lead=&HPF_LEAD

							out=work.out 
							outfor=work.outfor_lib&i.hier&j.model&m. 
							outstat=work.outstat
							outstatselect=work.outstatselect
							outmodelinfo=work.outmodelinfo
							outest=work.outest 
							scorerepository=work.scorerepository 
							outsum=work.outsum
							outcomponent=work.outcomponent
							inevent=_project.EventRepository;
							&&lib&i._by 
							id &HPF_TIMEID interval=&HPF_INTERVAL format=&HPF_TIMEID_FORMAT acc=total notsorted horizonstart=&HPF_HORIZON_START start=&HPF_START;
							forecast &HPF_DEPVAR1 /
							setmissing=&HPF_SETMISSING trimmiss=&HPF_TRIMMISS zeromiss=&HPF_ZEROMISS
							 ;
							stochastic &HPF_INDVARS  /  required=&HPF_REQUIRED setmissing=&HPF_SETMISSING trimmiss=RIGHT
							zeromiss=&HPF_ZEROMISS REPLACEMISSING ;
   					RUN;
								
					/***Join forecasts from candidates model into one table per series and rearrange output table***/
					Proc SQL nowarnrecurs ;

						CREATE TABLE outfor_lib&i.hier&j.(drop=&HPF_TIMEID)	
						AS SELECT t1.*,t2.&HPF_TIMEID as &time_id2, t2.predict as &&model&m. FROM outfor_lib&i.hier&j. AS t1
						RIGHT JOIN outfor_lib&i.hier&j.model&m. AS t2
						ON t1.&HPF_TIMEID = t2.&HPF_TIMEID
						; 

						DROP TABLE 	outfor_lib&i.hier&j.model&m. , out , outcomponent , outest , outmodelinfo , outstat , outstatselect , outsum
						;

					QUIT;
					
					

					%if &i. = 1 %then %do;

						DATA outfor_lib&i.hier&j. ;
							SET outfor_lib&i.hier&j. ;
								RENAME &time_id2 = &HPF_TIMEID ;
						RUN;

					%end;

					%else %if &i. > 1 %then %do;

						%let cntc = %eval(&i. - 1);

						DATA outfor_lib&i.hier&j.(drop=i k temp1-temp&cntc) ;
							RETAIN &HPF_TIMEID;
  								SET outfor_lib&i.hier&j.(rename=(&time_id2 = &HPF_TIMEID ));
								/* Put all character variables into an array */
 									array ch(*) _character_;
								/* You have to have an array for each of the arrays above */
								/* to hold the values that will replace missings.         */
 									array tempc(&cntc)$ temp1-temp&cntc;

								/* On the first observation, fill TEMPC with values */
								/* from each variable in CH array.                    */
									if _n_=1 then do;
									    do i=1 to dim(ch);
									       tempc(i)=ch(i);
									    end;
									end;
								/* On all other observations, if a variable has a missing value,*/
								/* assign the variable the current value of the TEMPC   */
								/* ...otherwise if it's a non-missing value, put that     */
								/* value into the TEMPC arrays                         */
									  else do;
									     do k=1 to &cntc;
									        if ch(k)=' ' then ch(k)=tempc(k);
									        else tempc(k)=ch(k);
									       end;
									  end;
								/* retain all variables that begin with 'temp' */
								RETAIN temp: ;

						RUN;



					%end;

				%end;


	
		%end;

	/*** append to level output tables ***/
	
	%let hier_outputs = ;
	%let hier_outputs_drop = ; 
	%do j=1 %to &&lib&i._nhierseries;
		%if &j.=1 %then %do;
			%let hier_outputs = outfor_lib&i.hier&j. ;
			%let hier_outputs_drop = outfor_lib&i.hier&j. ;
		%end;
		%else %do;
			%let hier_outputs = &hier_outputs outfor_lib&i.hier&j. ;
			%let hier_outputs_drop = &hier_outputs_drop, outfor_lib&i.hier&j. ;
		%end;
	%end;

	DATA &outforlib..outfor_lib&i. ;
	SET &hier_outputs;
	RUN;

	PROC SQL;
		DROP TABLE &hier_outputs_drop;
	QUIT;

%end;

	%fslogout();

%mend;





