
/* Use Data Set for Matrix 1 */
data tmp1; 
set sashelp.cars;
keep enginesize cylinders horsepower length mpg_city weight wheelbase;
run;

/* Data Set for Matrix " */
data tmp2;
set sashelp.cars;
keep enginesize cylinders horsepower length mpg_city weight wheelbase;

/* Modify one column to get different data */
enginesize=enginesize*(1+ranuni(23423));
run;



/* Assign arbitrary row and column for first and second matrix */

%let row1=5;
%let col1=1;
%let row2=7;
%let col2=3;
proc iml;

/* Read in data matrices */
  use tmp1;
  read all var _num_ into x;

  use tmp2;
  read all var _num_ into y;

  /* Make element wise comparisons */

  /* Equal Operator */
  a = x[&row1,&col1] = y[&row2,&col2]; print a;
  
  /* Unequal Operator */
  b = x[&row1,&col1] = y[&row2,&col2]; print b;

  /* Less Operator */
  c = x[&row1,&col1] < y[&row2,&col2]; print c;

    /* More or equal Operator */
  d = x[&row1,&col1] >= y[&row2,&col2]; print d;

quit;

