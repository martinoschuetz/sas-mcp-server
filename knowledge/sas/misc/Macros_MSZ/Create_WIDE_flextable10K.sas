options sql_ip_trace=(all);
options sastrace=',,,d' sastraceloc=saslog no$stsuffix details fullstimer;
options fullstimer msglevel=i DBIDIRECTEXEC=YES;* nonotes;
libname mylib sasiohna user=sdemo password=XXXX server="SRVxyz" instance=40 table_type=column;
options nosymbolgen nomlogic nomprint;
%macro table_generator_step1(table_name=,number_columns=,number_rows=);
	proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	    %if %sysfunc(exist(mylib.&table_name))=1 %then %do;  	execute ( drop table SDEMO.&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP1_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP1_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP2_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP2_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP3_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP3_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP4_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP4_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP5_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP5_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP6_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP6_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP8_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP8_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP7_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP7_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP9_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP9_&table_name )by sasiohna;	%end;
		%if %sysfunc(exist(mylib.TMP10_&table_name))=1 %then %do;  	execute ( drop table SDEMO.TMP10_&table_name )by sasiohna;	%end;
	quit;
	proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	%let start=%sysfunc(datetime());
	execute ( CREATE COLUMN TABLE SDEMO."&table_name" (Counter integer PRIMARY KEY, C1 float
														%do icount=2 %to 9979;
														                  ,C&icount. float
														%end;
														, LP float, Y float     ) 
				WITH SCHEMA FLEXIBILITY	) by sasiohna;
	disconnect from sasiohna;
	quit;

	data datos (keep= counter C:); 
		length counter 8;
		array C[&number_columns];
		do j=1 to &number_rows;
		     Counter=j;
		      do i=1 to &number_columns;
		     /*  C[i]=abs(rannor(0));
			   C[i]=C[i] - floor(C[i]);*/
			     C[i]=abs(rannor(0));
	           /*  C[i]=C[i] - floor(C[i])*/
		;
		       end;
		     output;
		end;
	run;

	data datos;
		set datos;
		lp= C1*1 %do icount=2 %to 9979; + C&icount.* &icount.  %end;
		
	    ;lp=lp-39000000; Lp=(1/Lp)*100000000;
		/*lp=lp-21000000;*/
		/* Returns a random variate from a binomial distribution. */
		lpfact=(1/((abs(lp))))*80;
		if lpfact ge 1 then lpfact=0.999999;
	    y = ranbin(1,1,lpfact);    
		if y le 0 then y=0;
		drop lpfact;
	    
    run;

    %let start2=%sysfunc(datetime());


	/* c1-c999*/
    Data datos1; 	set datos;keep counter c1-c999; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );

	execute ( CREATE COLUMN TABLE SDEMO."TMP1_&table_name" (Counter integer PRIMARY KEY, C1 float
														%do icount=2 %to 999;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP1_&table_name (insertbuff=32000) data=work.datos1 FORCE;run;

	/* c1000-c1997*/
    Data datos2; 	set datos;keep counter c1000-c1997; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP2_&table_name" (Counter integer PRIMARY KEY
														%do icount=1000 %to 1997;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP2_&table_name (insertbuff=32000) data=work.datos2 FORCE;run;

	/*c1998-c2995*/
	Data datos3; 	set datos;keep counter c1998-c2995; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP3_&table_name" (Counter integer PRIMARY KEY
														%do icount=1998 %to 2995;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP3_&table_name (insertbuff=32000) data=work.datos3 FORCE;run;

	/*c2996-c3993*/
	Data datos4; 	set datos;keep counter c2996-c3993; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP4_&table_name" (Counter integer PRIMARY KEY
														%do icount=2996 %to 3993;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP4_&table_name (insertbuff=32000) data=work.datos4 FORCE;run;

	/*5000 c3994-c4991*/
	Data datos5; 	set datos;keep counter c3994-c4991; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP5_&table_name" (Counter integer PRIMARY KEY
														%do icount=3994 %to 4991;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP5_&table_name (insertbuff=32000) data=work.datos5 FORCE;run;

	/* 6000 c4992-c5989*/
	Data datos6; 	set datos;keep counter c4992-c5989; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP6_&table_name" (Counter integer PRIMARY KEY
														%do icount=4992 %to 5989;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP6_&table_name (insertbuff=32000) data=work.datos6 FORCE;run;

	/*7000 c5990-c6987*/
	Data datos7; 	set datos;keep counter c5990-c6987; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP7_&table_name" (Counter integer PRIMARY KEY
														%do icount=5990 %to 6987;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP7_&table_name (insertbuff=32000) data=work.datos7 FORCE;run;

	/*8000 c6988-c7985*/
	Data datos8; 	set datos;keep counter c6988-c7985; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP8_&table_name" (Counter integer PRIMARY KEY
														%do icount=6988 %to 7985;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP8_&table_name (insertbuff=32000) data=work.datos8 FORCE;run;

	/*9000 c7986-c8983*/
	Data datos9; 	set datos;keep counter c7986-c8983; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP9_&table_name" (Counter integer PRIMARY KEY
														%do icount=7986 %to 8983;
														                  ,C&icount. float
														%end;
														     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP9_&table_name (insertbuff=32000) data=work.datos9 FORCE;run;

	/*10000 c8984-c9979*/
	Data datos10; 	set datos;keep counter c8984-c9979 LP Y; run;
     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( CREATE COLUMN TABLE SDEMO."TMP10_&table_name" (Counter integer PRIMARY KEY
														%do icount=8984 %to 9979;
														                  ,C&icount. float
														%end;
														, LP float, Y float     ) 
				) by sasiohna;
	disconnect from sasiohna;
	quit;
    proc append base=mylib.TMP10_&table_name (insertbuff=32000) data=work.datos10 FORCE;run;


	proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	%let start3=%sysfunc(datetime());

     proc SQL noprint exec;
	connect to sasiohna (user=sdemo password=XXXX server="SRVxyz" instance=40 );
	execute ( 
	insert into SDEMO."&table_name"  select A.COUNTER
	                    %do icount=1 %to 999; ,A.C&icount. %end;
						%do icount=1000 %to 1997; ,B.C&icount. %end;
						%do icount=1998 %to 2995; ,C.C&icount. %end;
						%do icount=2996 %to 3993; ,D.C&icount. %end;
						%do icount=3994 %to 4991; ,E.C&icount. %end;/*5000 c3994-c4991*/
						%do icount=4992 %to 5989; ,F.C&icount. %end;	/* 6000 c4992-c5989*/
						%do icount=5990 %to 6987; ,G.C&icount. %end;	/*7000 c5990-c6987*/
						%do icount=6988 %to 7985; ,H.C&icount. %end;	/*8000 c6988-c7985*/
						%do icount=7986 %to 8983; ,I.C&icount. %end;	/*9000 c7986-c8983*/
						%do icount=8984 %to 9979; ,J.C&icount. %end;/*10000 c8984-c9981*/
						, J.LP, J.Y
	from SDEMO.TMP1_&table_name as A, SDEMO.TMP2_&table_name as B, SDEMO.TMP3_&table_name as C, SDEMO.TMP4_&table_name as D,
	     SDEMO.TMP5_&table_name as E, SDEMO.TMP6_&table_name as F, SDEMO.TMP7_&table_name as G, SDEMO.TMP8_&table_name as H,
		 SDEMO.TMP9_&table_name as I, SDEMO.TMP10_&table_name as J

    where A.counter=B.counter and A.counter=C.counter and A.counter=D.counter and
	      A.counter=E.counter and A.counter=F.counter and A.counter=G.counter and
		  A.counter=H.counter and A.counter=I.counter and A.counter=J.counter


	) by sasiohna;
	disconnect from sasiohna;
	quit;
	
    %put PREPARE STEPS with %eval(&number_columns) columns and &number_rows rows.;
    %put Runtime Generate Data: %sysevalf(&start2. - &start.) seconds ; 
	%put Runtime Upload Tables: %sysevalf(&start3. - &start2.) seconds ; 
	%put Runtime Join and Insert UploadTables: %sysevalf(%sysfunc(datetime())-&start3.) seconds ; 

	proc SQL;
		select count (y) from mylib."&table_name"
		group by y;
	quit;

%mend;

%table_generator_step1(table_name=WIDE100K, number_columns=9979, number_rows=10000);