/* 	Data from the internet can be directly loaded into memory of LASR server without saving it to disk first.
	In other words, only one data step will be enough do the work. 
	See the following example that load a data set from UCI database to LASR.
*/
libname mylasr sasiola start=yes;
%let base = http://archive.ics.uci.edu/ml/machine-learning-databases;

data mylasr.spambase;
	infile "&base/spambase/spambase.data" device=url dsd dlm=',';
	input Make Address All _3d Our Over Remove Internet Order Mail Receive
		Will People Report Addresses Free Business Email You Credit Your Font
		_000 Money Hp Hpl George _650 Lab Labs Telnet _857 Data _415 _85
		Technology _1999 Parts Pm Direct Cs Meeting Original Project Re Edu
		Table Conference Semicol Paren Bracket Bang Dollar Pound Cap_Avg
		Cap_Long Cap_Total Class;
run;

proc imstat;
	table mylasr.spambase;
		fetch;
run;

quit;

libname mylasr clear;