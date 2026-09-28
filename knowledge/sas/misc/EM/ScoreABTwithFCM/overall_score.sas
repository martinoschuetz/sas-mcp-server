

%macro overall_score(OS=, path=,input_ds=,output_ds=);

%if &OS=W %then %let sign=\; %else %if &OS=L %then %let sign=/;

%macro drive(dir,ext);  

 
  %local filrf rc did memcnt name i;                                                                                                    
                                                                                                                                        
  /* Assigns a fileref to the directory and opens the directory */                                                           
  %let rc=%sysfunc(filename(filrf,&dir));                                                                                               
  %let did=%sysfunc(dopen(&filrf));                                                                                                     
                                                                                                                                        
  /* Make sure directory can be open */                                                                                                 
  %if &did eq 0 %then %do;                                                                                                              
   %put Directory &dir cannot be open or does not exist;                                                                                
   %return;                                                                                                                             
  %end;                                                                                                                                 
                                                                                                                                        
   /* Loops through entire directory */                                                                                                 
   %do i = 1 %to %sysfunc(dnum(&did));                                                                                                  
                                                                                                                                        
     /* Retrieve name of each file */                                                                                                   
     %let name=%qsysfunc(dread(&did,&i));                                                                                               
                                                                                                                                        
     /* Checks to see if the extension matches the parameter value */                                                                   
     /* If condition is true print the full name to the log        */                                                                   
      %if %qupcase(%qscan(&name,-1,.)) = %upcase(&ext) %then %do;                                                                       
    	data b;
			length a $300.;
			a="&dir.&sign.&name";
		run;
		proc append base=a data=b;
		run;                                                                                                                
      %end;                                                                                                                             
     /* If directory name call macro again */                                                                                           
      %else %if %qscan(&name,2,.) = %then %do;                                                                                          
        %drive(&dir.&sign.%unquote(&name),&ext)                                                                                               
      %end;                                                                                                                             
                                                                                                                                        
   %end;                                                                                                                                
                                                                                                                                        
  /* Closes the directory and clear the fileref */                                                                                      
  %let rc=%sysfunc(dclose(&did));                                                                                                       
  %let rc=%sysfunc(filename(filrf));                                                                                                    
                                                                                                                                        
%mend drive;                                                                                                                            
                                                                                                                                        
/* First parameter is the directory of where your files are stored. */                                                                  
/* Second parameter is the extension you are looking for.           */        

data a;
set _null_;
	length a $300.;
run;
%drive(&path.,sas);  

data codes;
set a;

if abs(index(a,'\score.sas ')-index(a,'/score.sas '))>0 then delete;
if a="" then delete;
if index(a,'optimizescore.sas ')>0 then mod_type="DS ";
else mod_type="DS2";

if mod_type="DS2" then do;
	check=index(a,'aStore.sas ');
	loc=substr(a,1,check-2);
end;
else loc="NA";

rename a=code;
run;
data a;
set _null_;
	length a $300.;
run;
%drive (&path.,sasast) ;

data stores;
set a;
	check=index(a,'score.sasast ');
	loc=substr(a,1,check-2);

rename a=store;

run;


PROC SQL;
   CREATE TABLE FINAL AS 
   SELECT t1.code, 
          t1.mod_type, 
          t2.store, 
          t1.loc
      FROM WORK.CODES t1
           LEFT JOIN WORK.STORES t2 ON (t1.loc = t2.loc);
QUIT;
	

%macro create_code_A (inputds=,outputds=);

data final_DS1;
	set final;
	if mod_type="DS ";
run;
data _null_;
	set final_DS1;
	call symputx ('dsl',_n_);
run;
%if %symexist (dsl) %then %do;
%if %eval(&dsl)>0 %then %do;

	data &outputds;
	set &inputds;
	run;

%do i=1 %to &dsl;
	data _null_;
	set FINAL_DS1;
	if _n_=&i and mod_type="DS" then call symputx ('code_a',code);
	run;
	data &outputds;
	set &outputds;
		%include "&code_a";

else treated&i.=0;
%end;
run;
	data &outputds;
	set &outputds;
	if nmiss(of treated:)=0 then t=0; else t=1;

	if t =0 then delete;
	drop treated: t;
	run;
%end;
%end;
%mend create_code_A;

%macro create_code_B (inputds=,outputds=);

data final_DS2;
	set final;
	if mod_type="DS2";
run;
data _null_;
	set final_DS2;
	call symputx ('dsl',_n_);
run;
%if %symexist (dsl) %then %do;

%if %eval(&dsl)>0 %then %do;


%do i=1 %to &dsl;
data _null_;
set final_DS2;
		if _n_=&i then do;
			call symputx ('code_b',code);
			call symputx('store',store);
	end;
run;

		%let _MM_InputDS=&inputds;
		%let _MM_OutputLib=work;
		%let _MM_OutputDs=out_&i;
		%let _MM_ModelStore=&store.;
		%let performance=performance details;
	%include "&code_b";
quit;
%if &i=1 %then %do;
	data &outputds;
	set out_&i.;
	run;
%end;
%else %do;
	proc append base=&outputds. data=out_&i.;
	run;
%end;
%end;	
%end;
%end;
%mend create_code_B;

%create_code_A(inputds=&input_ds,outputds=&output_ds.1)

%create_code_B(inputds=&input_ds,outputds=&output_ds.2)

%if %sysfunc(exist(&output_ds.1)) and %sysfunc(exist(&output_ds.2)) %then %do;

data &output_ds;
set &output_ds.1;
run;

proc append base=&output_ds data=&output_ds.2 force;
run;

%end;
%else %if %sysfunc(exist(&output_ds.1)) %then %do;
 
data &output_ds;
set &output_ds.1;
run;
%end;
 %else %if %sysfunc(exist(&output_ds.2)) %then %do;
data &output_ds;
set &output_ds.2;
run;
%end;

%else %put "There are no models in the folder";

%mend overall_score;

