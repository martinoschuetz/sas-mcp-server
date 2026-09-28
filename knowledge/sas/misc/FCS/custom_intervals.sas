/* 
Example for writing custom intervals.
http://sww.sas.com/saspedia/Writing_a_custom_interval_in_SAS
*/

/*
This is one way that you can define the custom interval. 
For demonstration, this interval is defined as custDAY using the intnx function.
To generate a more complex custom interval, you can manually enter in the dates as shown at the bottom of this article.
*/
options intervalds=(custDAY=daydata);

data daydata;
	do i=1 to 500;
		begin=intnx( 'day' , '01jan2005'd, i-1, 'b' );
		end=  intnx( 'day' , '01jan2005'd, i-1, 'e');

		output;
	end;

	format begin end date9.;
run;

/*
The following is an example of a custom monthly interval that begins each interval
on the first Saturday of the month and ends on the Friday which precedes the first Saturday of the next month.
Start the interval on first Saturday of the current month.
End the interval on the Friday prior to the first Saturday of the next month
*/
options intervalds=(FirstSaturday=custdata);

data custdata;
	do y=1980 to 2010;           /* range of year */
		do i=1 to 12;              /* range of months */
			date1=  nwkdom(1,7,i,y); /* first Saturday */

			if i ne 12 then
				do;
					date2=  nwkdom(1,7,i+1,y);
				end;
			else
				do;
					date2= nwkdom(1,7,1,y+1);
				end;

			begin= intnx('month',date1, 0, 'same' );
			end=   intnx('month',date2, 0, 'same' )-1;

			dayofweek=  (begin);
			dayofweek2= (end);
			output;
		end;
	end;

	format date1 date2 begin end date9.
		dayofweek dayofweek2 downame10.;
run;

/*
One additional way to create a custom interval is to manually enter in the dates like the following example. 
One must note that this example does not have an "end" variable. The custom interval only requires a start variable. 
The end will be assumed to be one date prior to the
*/
options intervalds=(cycles=custint);

data custint;
	input UNITS @11 begin date9.;
	lines;

	299.38    12MAR04
	323.87    31MAR04
	333.27    20APR04
	296.36    10MAY04
	237.17    27MAY04
	359.19    15JUN04
	684.64    02JUL04
	770.48    21JUL04
	658.56    09AUG04
	885.38    26AUG04
	242.25    16SEP04
	605.73    06OCT04
	826.13    27OCT04
	957.84    18NOV04
	975.69    09DEC04
	242.14    31DEC04
	448.86    18JAN05
	455.15    04FEB05
	525.84    24FEB05
	490.41    15MAR05
	362.99    01APR05
	452.57    20APR05
	847.31    10MAY05
	223.93    28MAY05
	006.37    16JUN05
	091.19    02JUL05
	396.77    21JUL05
	620.67    09AUG05
	866.85    26AUG05
	813.04    16SEP05
	573.34    06OCT05
	928.87    27OCT05
	003.31    19NOV05
	948.39    10DEC05
	511.75    30DEC05
	508.89    18JAN06
	683.78    07FEB06
	303.12    23FEB06
	790.15    15MAR06
	176.93    31MAR06
	938.41    19APR06
	273.12    09MAY06
	667.13    26MAY06
	788.10    14JUN06
	887.77    04JUL06
	480.34    22JUL06
	908.51    11AUG06
	219.56    30AUG06
	544.56    19SEP06
	755.38    07OCT06
	250.94    28OCT06
	941.83    18NOV06
	867.33    08DEC06
	607.37    29DEC06
	448.94    17JAN07
	607.66    03FEB07
	324.70    24FEB07
	495.56    14MAR07
	560.41    31MAR07
	801.29    19APR07
	299.80    09MAY07
	098.23    26MAY07
	775.01    15JUN07
	805.03    04JUL07
	767.08    23JUL07
	619.03    10AUG07
	370.76    29AUG07
	387.62    18SEP07
	658.92    07OCT07
	273.71    26OCT07
	137.08    18NOV07
	546.21    07DEC07
	;