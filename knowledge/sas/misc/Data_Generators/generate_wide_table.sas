%let number_columns=1000;
%let rows_per_column=100;
%let number_rows=%eval(&number_columns. * &rows_per_column.);
%let scale=0.000001;

%macro generate_wide_table;

data datos (keep= counter C:);
	length counter 8;
	array C[&number_columns];

	do j=1 to &number_rows;
		Counter=j;

		do i=1 to &number_columns;
			/* 	Since 3 sigma contains 99% of the data,
				the mean shift will reduce the production of negative values
				which lead to issues with the exp function, see below. */
			C[i]=3+rannor(0);
		end;

		output;
	end;
run;

data datos;
	set datos;
	lp= C1*1

		%do icount=2 %to &number_columns;
			+ C&icount.* &icount.
		%end;
	;
	lp_scaled = &scale. * lp;
	y = ranbin(1,1,(1/(1+exp(lp_scaled))));
run;

%mend;

%generate_wide_table;

proc hpsummary data=datos;
	class y;
	output out=y_stat;
run;
data y_stat;
	set y_stat;
	Perc = _FREQ_/&number_rows.;
run;

proc hpsummary data=datos;
	var lp_scaled;
	output min=Min P25=P25 median=Median P75=P75 max=Max out=lp_scaled_stat;
run;