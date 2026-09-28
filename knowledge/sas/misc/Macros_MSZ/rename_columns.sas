%macro rename_columns(lib=,ds=,str=,pre_suf_ix=,filter_pre=);

	proc contents data=&lib..&ds. out=hlp noprint; run;

	proc sql noprint;
		%if  %str(%upcase(&pre_suf_ix.)) = PRE %then %do;
			%put "PRE";
   			select cats(name,"=","&str._",name)
   		%end;
   		%else %do;
   			%put "SUFFIX";
    		select cats(name,"=",name,"_&str.")
   		%end;   			
   	      	into :list
          	separated by " "
          	from hlp
          	where name like "&filter_pre.%";
	quit;
	%put &=list.;

	proc datasets library = &lib. nolist;
   		modify &ds.;
   		rename &list;
	quit;

%mend rename_columns;
/*
data one;
   input id name :$10. age score1 score2 score3;
   datalines;
1 George 10 85 90 89
2 Mary 11 99 98 91
3 John 12 100 100 100
4 Susan 11 78 89 100
;
run;

%rename_columns(lib=work,ds=one,str=Acceleration_X,pre_suf_ix=pre,filter_pre=score);

data two;
   input id name :$10. age score1 score2 score3;
   datalines;
1 George 10 85 90 89
2 Mary 11 99 98 91
3 John 12 100 100 100
4 Susan 11 78 89 100
;
run;

%rename_columns(lib=work,ds=two,str=Acceleration_X,pre_suf_ix=suffix,filter_pre=score);
*/