options sql_ip_trace=(all);
options sastrace=',,,d' sastraceloc=saslog no$stsuffix details;
options fullstimer msglevel=i;

* nonotes;
libname mylib sasiohna user=sdemo password=Sdemo2014 server="ld9400" instance=40 table_type=column;
* libname mylib "c:\tmp";

%macro table_generator2(table_name=,number_columns=,number_rows=);

	proc SQL noprint exec;
		connect to sasiohna (user=sdemo password=Sdemo2014 server="ld9400" instance=40 autocommit=yes );
		execute ( drop table SDEMO."&table_name" )by sasiohna;
		%let start=%sysfunc(datetime());
		execute ( 
			CREATE COLUMN TABLE SDEMO."&table_name" (Counter integer PRIMARY KEY, C1 float

			%do;
				icount=2 %to &number_columns;
					,C&icount. float
			%end;
		) WITH SCHEMA FLEXIBILITY ) by sasiohna;
		execute ( commit )by sasiohna;
		disconnect from sasiohna;
	quit;

	data datos (keep=C:);
		length counter 8;
		array C[&number_columns];

		do j=1 to &number_rows;
			Counter=j;

			do i=1 to &number_columns;
				C[i]=rannor(0);
			end;

			output;
		end;
	run;

	/*proc append base=mylib.&table_name (insertbuff=32000) data=work.datos;run;*/
	proc SQL;
		insert into mylib.&table_name (insertbuff=32000) select counter, c1-c1000  from work.datos (keep=counter c1-c1000);
	quit;

	%put Runtime: %sysevalf(%sysfunc(datetime())-&start) seconds with %eval(&number_columns) columns and &number_rows rows.;
%mend;

%table_generator2(table_name=CHRISTAB, number_columns=2046, number_rows=10);